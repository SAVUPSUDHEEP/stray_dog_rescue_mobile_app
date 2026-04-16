import uuid
import math

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_bcrypt import Bcrypt

import tensorflow as tf
from tensorflow.keras.applications.xception import preprocess_input

from PIL import Image
import numpy as np
import os
import sqlite3
from database import create_tables
from ultralytics import YOLO
import google.generativeai as genai



# -------------------- HAVERSINE --------------------
def haversine(lat1, lon1, lat2, lon2):
    """Return distance in km between two GPS points."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def find_nearest_shelter(lat, lon, conn):
    """Return (shelter_id, shelter_name, admin_username) of the nearest shelter."""
    cur = conn.cursor()
    shelters = cur.execute(
        "SELECT id, name, latitude, longitude FROM shelters WHERE type='shelter'"
    ).fetchall()
    if not shelters:
        return None, None, None
    nearest = min(shelters, key=lambda s: haversine(lat, lon, s[2], s[3]))
    shelter_id = nearest[0]
    shelter_name = nearest[1]
    # Find the admin account linked to this shelter
    row = cur.execute(
        "SELECT username FROM users WHERE shelter_id=? AND role='shelter' LIMIT 1",
        (shelter_id,)
    ).fetchone()
    admin_username = row[0] if row else "shelter1"
    return shelter_id, shelter_name, admin_username


# -------------------- DB --------------------
def get_db():
    conn = sqlite3.connect("rescue.db")
    conn.row_factory = sqlite3.Row
    return conn


# -------------------- APP --------------------
app = Flask(__name__)
# Enable CORS for all routes and origins (required for Flutter Web)
CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=True)
app.config['JWT_SECRET_KEY'] = 'super-secret-key-change-this'

jwt = JWTManager(app)
bcrypt = Bcrypt(app)


# -------------------- INIT DB --------------------
print("Creating database tables...")
create_tables()
print("Database ready.")


# -------------------- MODEL --------------------
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_PATH = os.path.join(BASE_DIR, "model", "best_xception_model_finetuned.h5")
model = tf.keras.models.load_model(MODEL_PATH)

# YOLOv8 Injury Detection Model
YOLO_MODEL_PATH = os.path.join(BASE_DIR, "model", "dog_injury_best.pt")
yolo_model = YOLO(YOLO_MODEL_PATH)


# -------------------- UPLOAD --------------------
UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


# -------------------- BREEDS --------------------
class_names = [
    "Border_collie",
    "Cardigan",
    "toy_poodle",
    "Bichon_Frise",
    "chinese_rural_dog",
    "Labrador_retriever",
    "golden_retriever",
    "miniature_schnauzer",
    "samoyed",
    "teddy"
]


# =====================================================
# HOME
# =====================================================
@app.route("/")
def home():
    return "Dog Rescue Backend Running"

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

# =====================================================
# PREDICT BREED (UTILITY)
# =====================================================
@app.route("/predict_breed", methods=["POST"])
def predict_breed_api():
    if "file" not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    file = request.files["file"]
    try:
        from tensorflow.keras.applications.xception import preprocess_input
        img = Image.open(file.stream).convert("RGB").resize((224, 224))
        img = np.array(img).astype(np.float32)
        img = preprocess_input(img)
        img = np.expand_dims(img, axis=0)
        
        preds = model.predict(img)
        breed = class_names[np.argmax(preds)]
        return jsonify({"breed": breed})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# =====================================================
# VALIDATE PHOTO (GEMINI AI)
# =====================================================
@app.route("/validate_photo", methods=["POST"])
def validate_photo():
    if "file" not in request.files:
        return jsonify({"valid": False, "reason": "No image uploaded"}), 400

    file = request.files["file"]
    try:
        img = Image.open(file.stream).convert("RGB")
        
        prompt = "Look at this image. Is it a clear, well-lit photo where a dog is clearly visible? Reply with exactly YES or NO on the first line, and give a short 1-sentence reason on the second line."
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content([prompt, img])
        
        text_lines = [line.strip() for line in response.text.strip().split('\n') if line.strip()]
        if text_lines and "YES" in text_lines[0].upper():
            return jsonify({"valid": True, "reason": "Looks good."})
        else:
            reason = text_lines[1] if len(text_lines) > 1 else "The dog is not clearly visible in this picture."
            return jsonify({"valid": False, "reason": reason})
    except Exception as e:
        # Fallback to true if AI fails
        return jsonify({"valid": True, "reason": f"AI fallback: {str(e)}"})


# =====================================================
# REPORT CASE
# =====================================================
@app.route("/report", methods=["POST"])
def report():

    if "file" not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    file = request.files["file"]

    latitude  = request.form.get("latitude",  type=float)
    longitude = request.form.get("longitude", type=float)

    unique_name = f"{uuid.uuid4()}_{file.filename}"
    path = os.path.join(UPLOAD_FOLDER, unique_name)
    file.save(path)

    # Image preprocessing
    img = Image.open(path).convert("RGB").resize((224, 224))
    img = np.array(img).astype(np.float32)
    img = preprocess_input(img)
    img = np.expand_dims(img, axis=0)

    # --- Run Models in Parallel ---
    # 1. Breed Prediction (Xception)
    preds = model.predict(img)
    breed = class_names[np.argmax(preds)]

    # 2. Injury Detection (YOLOv8)
    # Process the same saved image path
    yolo_results = yolo_model.predict(path, conf=0.25)
    
    # Check for any bounding box with class 'injury'
    is_injured = False
    for result in yolo_results:
        for box in result.boxes:
            class_id = int(box.cls[0])
            label = result.names[class_id]
            if label.lower() == "injury":
                is_injured = True
                break
        if is_injured: break

    injury_status = "Injured" if is_injured else "Not Injured"
    ai_injury_status = injury_status  # explicit AI field
    case_status   = "reported"

    # ── Triage fields from chatbot (optional) ──
    reported_injury_status = request.form.get("reported_injury_status")  # yes / no / not sure
    reported_injury_type   = request.form.get("reported_injury_type")    # bleeding, limping …
    reported_severity      = request.form.get("reported_severity")       # mild / moderate / severe …

    # ── Priority logic ──
    if reported_injury_status == "yes":
        priority = "HIGH"
    elif ai_injury_status == "Injured":
        priority = "HIGH"
    else:
        priority = "NORMAL"

    conn   = get_db()
    cursor = conn.cursor()

    # ── Find nearest shelter ──
    shelter_id, shelter_name, admin_username = None, None, "shelter1"
    if latitude is not None and longitude is not None:
        shelter_id, shelter_name, admin_username = find_nearest_shelter(
            latitude, longitude, conn
        )

    # ── Insert case ──
    cursor.execute("""
        INSERT INTO cases (
            image_path, predicted_breed, injury_status,
            ai_injury_status, reported_injury_status, reported_injury_type,
            reported_severity, priority,
            latitude, longitude, case_status, shelter_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        unique_name, breed, injury_status,
        ai_injury_status, reported_injury_status, reported_injury_type,
        reported_severity, priority,
        latitude, longitude, case_status, shelter_id
    ))
    conn.commit()

    cursor.execute("SELECT last_insert_rowid()")
    case_id = cursor.fetchone()[0]

    # ── Notify the assigned shelter admin ──
    shelter_label = shelter_name or "your shelter"
    cursor.execute("""
        INSERT INTO notifications (username, title, type, message)
        VALUES (?, ?, ?, ?)
    """, (
        admin_username,
        "New Case Reported" + (" ⚠️ HIGH PRIORITY" if priority == "HIGH" else ""),
        "case",
        f"A new rescue case (ID: {case_id}) has been assigned to {shelter_label}."
        + (f" Priority: {priority}." if priority == "HIGH" else "")
    ))
    
    # ── Also Notify Master Admin (shelter1) if different ──
    if admin_username != "shelter1":
        cursor.execute("""
            INSERT INTO notifications (username, title, type, message)
            VALUES (?, ?, ?, ?)
        """, (
            "shelter1",
            "New Case Reported" + (" ⚠️ HIGH PRIORITY" if priority == "HIGH" else ""),
            "case",
            f"A new rescue case (ID: {case_id}) has been assigned to {shelter_label}."
            + (f" Priority: {priority}." if priority == "HIGH" else "")
        ))

    conn.commit()
    conn.close()

    return jsonify({
        "case_id":      case_id,
        "case_status":  case_status,
        "shelter_id":   shelter_id,
        "shelter_name": shelter_name,
        "priority":     priority,
    })


# =====================================================
# CHATBOT AI TOOLS & CONFIG
# =====================================================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "AIzaSyChogrWdAJQiOMdOUlzJORibf4eHbZvp4Q")
genai.configure(api_key=GEMINI_API_KEY)

def get_available_dogs(breed: str = None, age: int = None, gender: str = None, color: str = None):
    """Fetches available dogs with optional filters for breed, age, gender, and color. Returns a summary list."""
    conn = get_db()
    cur = conn.cursor()
    query = "SELECT id, breed, age, gender, color FROM adoption WHERE status='available'"
    params = []
    
    if breed:
        query += " AND breed LIKE ?"
        params.append(f"%{breed}%")
    if age:
        query += " AND age = ?"
        params.append(age)
    if gender:
        query += " AND gender LIKE ?"
        params.append(f"{gender}%")
    if color:
        query += " AND color LIKE ?"
        params.append(f"%{color}%")
        
    rows = cur.execute(query, params).fetchall()
    conn.close()
    if not rows:
        return "No dogs match those specific criteria currently."
    return "\n".join([f"ID: {r['id']}, Breed: {r['breed']}, Age: {r['age']}, Gender: {r['gender']}, Color: {r['color']}" for r in rows])

def get_dog_details(dog_id: int):
    """Fetches all details for a specific dog by ID, including its photo. Call this when a user selects a dog or asks for more info/images."""
    conn = get_db()
    cur = conn.cursor()
    dog = cur.execute("SELECT * FROM adoption WHERE id=?", (dog_id,)).fetchone()
    conn.close()
    
    if not dog:
        return f"Sorry, I couldn't find any dog with ID {dog_id}."
        
    # Format a beautiful response including the image URL tag for the app to parse
    # First, handle the path to ensure it doesn't have double 'uploads' and uses correct slashes
    raw_path = dog['image_path'].split(',')[0]
    clean_path = raw_path.replace('\\', '/').split('/')[-1]

    details = (
        f"Detailed Profile for {dog['dog_name']} (ID: {dog['id']}):\n"
        f"- Breed: {dog['breed']}\n"
        f"- Age: {dog['age']} years\n"
        f"- Gender: {dog['gender']}\n"
        f"- Color: {dog['color']}\n"
        f"- Vaccination Status: {dog['vaccination_status']}\n"
        f"- Behavior & Personality: {dog['behavior_description']}\n"
        f"- Current Location: {dog['location']}\n"
        f"\nIMAGE_URL:http://192.168.29.96:5000/uploads/{clean_path}"
    )
    return details

def create_adoption_request(username: str, phone: str, address: str, dog_id: int):
    """Submits an adoption request for a specific dog. ONLY call this if you have the user's username, phone, address, and the dog_id. Ask for them if missing."""
    conn = get_db()
    cur = conn.cursor()
    
    dog = cur.execute("SELECT * FROM adoption WHERE id=? AND status='available'", (dog_id,)).fetchone()
    if not dog:
        conn.close()
        return f"Error: Dog with ID {dog_id} is not available for adoption."
        
    cur.execute("""
        INSERT INTO adoption_requests (adoption_id, user_name, phone, address, status)
        VALUES (?, ?, ?, ?, "pending")
    """, (dog_id, username, phone, address))
    conn.commit()
    conn.close()
    return f"Success! Adoption request submitted for dog ID {dog_id}. The shelter will contact {username} soon."

def get_shelter_info():
    """Provides general information and contact details about the street dog rescue shelter."""
    return "Street Dog Rescue Center. We help injured and abandoned street dogs. Contact us at 555-1234 or visit our app to report cases or adopt."

chat_tools = [get_available_dogs, get_dog_details, create_adoption_request, get_shelter_info]
chat_instruction = (
    "You are the Street Dog Rescue & Pet Care Assistant. Your tone is empathetic, friendly, and highly knowledgeable about dogs.\n\n"
    "Follow these strict guidelines:\n"
    "1. CORE MISSION: Assist users with dog adoption, finding shelter info, and answering general pet care or dog health questions.\n"
    "2. OFF-TOPIC QUESTIONS: If the user asks about anything entirely unrelated to dogs, pets, or the rescue shelter (like politics, math, coding, etc.), politely inform them that you are a specialized Dog Rescue Assistant and gently steer the conversation back to dogs or shelter services.\n"
    "3. PET CARE ADVICE: Feel free to answer questions about dog health, training, diet, behavioral issues, and general concerns. Always add a brief disclaimer to consult a real vet for serious or life-threatening medical issues.\n"
    "4. RESCUE TRIAGE FLOW — CRITICAL:\n"
    "   - TRIGGER: If the user says something like 'I see a stray dog', 'found a dog', 'there is a dog on the road', 'injured dog near me', 'dog needs help', or any variation of spotting/finding a dog, DO NOT immediately ask for a photo.\n"
    "   - STEP 1: First ask: 'Got it! 🐾 Let me help you report this. Is the dog injured?' and present three options clearly: 'Yes 🤕', 'No ✅', 'Not sure 🤔'. Wait for the user to respond.\n"
    "   - STEP 2 (only if they said Yes or Not sure): Ask: 'What kind of injury do you notice? You can describe it or pick one: Bleeding 🩸, Broken leg 🦴, Limping 🐕, Wound, Fracture, Skin issue, Unable to walk, Unknown'. Wait for response.\n"
    "   - STEP 3: Ask: 'How severe does it look? Pick one: Mild, Moderate, Severe, Critical, Not sure'. Wait for response.\n"
    "   - STEP 4: After getting severity (or after Step 1 if user says 'No'), say: 'Thank you for those details! Now please tap the 📷 camera icon below to upload a photo of the dog. Our AI will analyze the image and the nearest rescue team will be alerted immediately.'\n"
    "   - IMPORTANT: Do NOT ask for the user's name, phone, or address during rescue triage. Just collect injury info then ask for photo.\n"
    "   - IMPORTANT: Each step must wait for the user's response before proceeding to the next. Do not ask multiple questions at once.\n"
    "5. ADOPTIONS (INTERACTIVE FLOW):\n"
    "   - Phase 1: If a user wants to adopt, do NOT just list all dogs. Instead, ask them for their preferences: 'Great! To help you find the right companion, what kind of breed do you prefer? Any preference for age or gender?'\n"
    "   - Phase 2: Once they provide preferences, use the 'get_available_dogs' tool with those filters. If no dogs match, tell them 'I don't have any dogs matching that exact description right now, but here are some other wonderful dogs...' and show a broader list or ask if they have other preferences.\n"
    "   - Phase 3: When a user identifies a dog they like (by ID or breed), use 'get_dog_details' to show their full personality and provide their photo. You MUST include the text 'IMAGE_URL:' followed by the full image link at the end of your message so the app can display it. Example: 'IMAGE_URL:http://192.168.1.5:5000/uploads/dog.jpg'. Do NOT omit the 'IMAGE_URL:' prefix.\n"
    "   - Phase 4: If the user decides to adopt a specific dog, use the 'create_adoption_request' tool. You MUST ask for their username, phone number, and address BEFORE calling this tool.\n"
    "6. RESCUES & EMERGENCIES: If a user reports an injured, aggressive, or trapped street dog, follow the RESCUE TRIAGE FLOW above first. After they complete triage, instruct them to tap the '📷 Camera' icon to upload an image with GPS location.\n"
    "7. SURRENDERS: If a user brings up surrendering a dog, explain our policy and instruct them to navigate to the 'Surrender Pet' section in the mobile app where they can fill out the required detailed forms."
)

try:
    chat_model = genai.GenerativeModel('gemini-2.5-flash', tools=chat_tools, system_instruction=chat_instruction)
except Exception:
    chat_model = None

# =====================================================
# CHATBOT (AI-BASED)
# =====================================================
@app.route("/chat", methods=["POST"])
def chat():
    data = request.json
    if not data or "message" not in data:
        return jsonify({"response": "Please send a message."}), 400
        
    msg = data["message"]
    history = data.get("history", [])
    
    if chat_model is None:
        return jsonify({"response": "I am currently disconnected from my AI brain. Please ensure the server has a valid GEMINI_API_KEY set!"})
        
    formatted_history = []
    for h in history:
        role = "user" if h.get("isUser") else "model"
        formatted_history.append({"role": role, "parts": [h.get("text", "")]})
        
    # Gemini requires user message to be first
    while formatted_history and formatted_history[0]["role"] == "model":
        formatted_history.pop(0)
        
    try:
        chat_session = chat_model.start_chat(
            history=formatted_history, 
            enable_automatic_function_calling=True
        )
        response = chat_session.send_message(msg)
        return jsonify({"response": response.text})
    except Exception as e:
        return jsonify({"response": f"Sorry, I encountered an error: {str(e)}"})

# =====================================================
# GET CASES
# =====================================================
@app.route("/cases", methods=["GET"])
def get_cases():

    shelter_id = request.args.get("shelter_id", type=int)

    conn = get_db()
    cur  = conn.cursor()

    if shelter_id:
        rows = cur.execute(
            "SELECT * FROM cases WHERE shelter_id = ? ORDER BY id DESC",
            (shelter_id,)
        ).fetchall()
    else:
        rows = cur.execute("SELECT * FROM cases ORDER BY id DESC").fetchall()

    conn.close()
    return jsonify([dict(r) for r in rows])


# =====================================================
# UPDATE CASE STATUS
# =====================================================
@app.route("/cases/<int:id>", methods=["PUT"])
def update_case(id):
    data = request.json
    status = data.get("case_status")
    vaccination_status = data.get("vaccination_status")
    medical_notes = data.get("medical_notes")

    conn = get_db()
    cur = conn.cursor()

    # Dynamic update query
    updates = []
    params = []
    if status:
        updates.append("case_status=?")
        params.append(status)
    if vaccination_status:
        updates.append("vaccination_status=?")
        params.append(vaccination_status)
    if medical_notes is not None:
        updates.append("medical_notes=?")
        params.append(medical_notes)

    if not updates:
        return jsonify({"message": "No fields to update"}), 400

    params.append(id)
    query = f"UPDATE cases SET {', '.join(updates)} WHERE id=?"
    cur.execute(query, params)

    conn.commit()
    conn.close()

    return jsonify({"message": "Updated"})


# =====================================================
# SUBMIT SURRENDER + NOTIFY ADMIN
# =====================================================
@app.route("/surrender", methods=["POST"])
def surrender():

    files = request.files.getlist("files")
    saved_filenames = []
    
    for file in files:
        if file.filename:
            filename = f"{uuid.uuid4()}_{file.filename}"
            path = os.path.join(UPLOAD_FOLDER, filename)
            file.save(path)
            saved_filenames.append(filename)
            
    # Store multiple filenames as a comma-separated string
    image_paths_str = ",".join(saved_filenames) if saved_filenames else None

    with open("debug_form.txt", "a") as f:
        f.write(f"DEBUG: Surrender request form data: {dict(request.form)}\n")
    conn = get_db()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO surrender
        (image_path, user_name, reason, phone, behavior, allergies, food,
         breed, age, gender, vaccinated, latitude, longitude, notes, status)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    """, (
        image_paths_str,
        request.form.get("username"),
        request.form.get("reason"),
        request.form.get("phone"),
        request.form.get("behavior"),
        request.form.get("allergies"),
        request.form.get("food"),
        request.form.get("breed"),
        request.form.get("age"),
        request.form.get("gender"),
        request.form.get("vaccinated"),
        request.form.get("latitude"),
        request.form.get("longitude"),
        request.form.get("notes"),
        "pending"
    ))

    surrender_id = cur.lastrowid

    # 🔔 Notify Admin
    cur.execute("""
        INSERT INTO notifications (username, title, message, type, reference_id)
        VALUES (?, ?, ?, ?, ?)
    """, (
        "shelter1",  # change if your admin username differs
        "New Surrender Request",
        "A new surrender request has been submitted.",
        "surrender_request",
        surrender_id
    ))

    conn.commit()
    conn.close()

    return jsonify({"message": "Surrender submitted"})

# =====================================================
# GET SURRENDERS
# =====================================================
@app.route("/surrenders", methods=["GET"])
def get_surrenders():

    conn = get_db()
    cur = conn.cursor()

    rows = cur.execute("SELECT * FROM surrender").fetchall()
    conn.close()

    return jsonify([dict(r) for r in rows])

## =====================================================
# UPDATE SURRENDER STATUS + NOTIFY USER
# =====================================================
@app.route("/surrender/<int:id>", methods=["PUT"])
def update_surrender(id):

    data = request.json
    status = data.get("status")

    conn = get_db()
    cur = conn.cursor()

    # Get username from surrender request
    row = cur.execute("""
        SELECT user_name FROM surrender WHERE id=?
    """, (id,)).fetchone()

    if not row:
        return jsonify({"error": "Surrender not found"}), 404

    username = row["user_name"]

    # Update surrender status
    cur.execute("""
        UPDATE surrender
        SET status=?
        WHERE id=?
    """, (status, id))

    # Prepare notification
    if status == "approved":
        title = "Surrender Approved"
        message = "Your surrender request for the dog has been approved. The shelter will proceed with adoption processing."
    else:
        title = "Surrender Rejected"
        message = "Your surrender request was rejected. Please contact the shelter for more information."

    # Insert notification if username exists
    if username:
        print(f"DEBUG: Sending surrender notification to user: {username}")
        cur.execute("""
            INSERT INTO notifications (username, title, message, type, reference_id)
            VALUES (?, ?, ?, ?, ?)
        """, (
            username,
            title,
            message,
            "surrender_status",
            id
        ))
    else:
        print(f"DEBUG: No username found for surrender ID {id}. Skipping notification.")

    conn.commit()
    conn.close()

    return jsonify({"message": "Surrender updated and user notified"})
# MOVE TO ADOPTION (MAIN FEATURE)
# =====================================================
@app.route("/move_to_adoption", methods=["POST"])
def move_to_adoption():

    if request.content_type and request.content_type.startswith('multipart/form-data'):
        data = request.form
    else:
        data = request.json

    source = data["source"]
    sid = data.get("id")
    if sid:
        sid = int(sid)
    
    # New fields coming from frontend
    dog_name = data.get("dog_name", "Unknown")
    color = data.get("color", "Unknown")
    vaccination_status = data.get("vaccination_status", "Unknown")
    behavior_description = data.get("behavior_description", "Unknown")

    conn = get_db()
    cur = conn.cursor()

    breed = data.get("breed", "Unknown")
    age = data.get("age", "Unknown")
    gender = data.get("gender", "Unknown")
    
    uploaded_image = None
    if "file" in request.files and request.files["file"].filename:
        import uuid
        file = request.files["file"]
        unique_name = f"{uuid.uuid4()}_{file.filename}"
        path = os.path.join(UPLOAD_FOLDER, unique_name)
        file.save(path)
        uploaded_image = unique_name

    image = None

    if source == "case":

        row = cur.execute(
            "SELECT * FROM cases WHERE id=?",
            (sid,)
        ).fetchone()

        if not row:
            return jsonify({"error": "Case not found"}), 404
            
        # Overwrite breed, age, gender with form data if provided
        if breed == "Unknown":
            breed = row["predicted_breed"]
            
        image = uploaded_image if uploaded_image else row["image_path"]

    elif source == "surrender":

        row = cur.execute(
            "SELECT * FROM surrender WHERE id=?",
            (sid,)
        ).fetchone()

        if not row:
            return jsonify({"error": "Not found"}), 404

        if breed == "Unknown":
            breed = row["breed"]
        if age == "Unknown":
            age = row["age"]
        if gender == "Unknown":
            gender = row["gender"]
            
        image = uploaded_image if uploaded_image else row["image_path"]

        cur.execute(
            "UPDATE surrender SET status='completed' WHERE id=?",
            (sid,)
        )
        
        # Insert notification for surrender approval explicitly here as well, covering both paths
        username = row["user_name"]
        if username:
            print(f"DEBUG: Sending move-to-adoption notification to user: {username}")
            title = "Surrender Approved"
            message = "Your surrender request for the dog has been approved. The shelter will proceed with adoption processing."
            cur.execute("""
                INSERT INTO notifications (username, title, message, type, reference_id)
                VALUES (?, ?, ?, ?, ?)
            """, (
                username,
                title,
                message,
                "surrender_status",
                sid
            ))
        else:
            print(f"DEBUG: No username found for surrender ID {sid} during move-to-adoption. Skipping notification.")

    else:
        return jsonify({"error": "Invalid source"}), 400

    cur.execute("""
        INSERT INTO adoption
        (source_type, source_id, dog_name, breed, color, age, gender, vaccination_status, behavior_description, location, image_path, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        source,
        sid,
        dog_name,
        breed,
        color,
        age,
        gender,
        vaccination_status,
        behavior_description,
        "Shelter",
        image,
        "available"
    ))

    conn.commit()
    conn.close()

    return jsonify({"message": "Added to adoption"})

# =====================================================
# GET ADOPTION LIST
# =====================================================
@app.route("/adoptions", methods=["GET"])
def get_adoptions():

    conn = get_db()
    cur = conn.cursor()

    rows = cur.execute("""
        SELECT * FROM adoption
        WHERE status='available'
    """).fetchall()

    conn.close()

    return jsonify([dict(r) for r in rows])

# =====================================================
# CREATE ADOPTION REQUEST
# =====================================================
@app.route("/adoption_request", methods=["POST"])
def create_adoption_request():

    data = request.json

    adoption_id = data.get("adoption_id")
    username = data.get("username")
    phone = data.get("phone")
    address = data.get("address")

    conn = get_db()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO adoption_requests
        (adoption_id, user_name, phone, address, status)
        VALUES (?, ?, ?, ?, 'pending')
    """, (
        adoption_id,
        username,
        phone,
        address
    ))
    
    # 🔔 Notify shelter
    cur.execute("""
    INSERT INTO notifications (username, title, message, type, reference_id)
    VALUES (?, ?, ?, ?, ?)
""", (
    "shelter1",
    "New Adoption Request",
    f"{username} requested to adopt a dog.",
    "adoption_request",
    adoption_id
))

    conn.commit()
    conn.close()

    return jsonify({"message": "Adoption request submitted"})
# =====================================================
# GET ADOPTION REQUESTS (ADMIN)
# =====================================================
@app.route("/adoption_requests", methods=["GET"])
def get_adoption_requests():

    conn = get_db()
    cur = conn.cursor()

    rows = cur.execute("""
        SELECT * FROM adoption_requests
        ORDER BY created_at DESC
    """).fetchall()

    conn.close()

    return jsonify([dict(r) for r in rows])
# =====================================================
# =====================================================
# UPDATE ADOPTION REQUEST STATUS + CREATE NOTIFICATION
# =====================================================
@app.route("/adoption_requests/<int:id>", methods=["PUT"])
def update_adoption_request(id):

    data = request.json
    status = data.get("status")

    conn = get_db()
    cur = conn.cursor()

    # Get request info
    row = cur.execute("""
        SELECT adoption_id, user_name
        FROM adoption_requests
        WHERE id=?
    """, (id,)).fetchone()

    if not row:
        return jsonify({"error": "Request not found"}), 404

    adoption_id = row["adoption_id"]
    username = row["user_name"]

    # Update request status
    cur.execute("""
        UPDATE adoption_requests
        SET status=?
        WHERE id=?
    """, (status, id))

    # If approved → mark dog adopted
    if status == "approved":
        cur.execute("""
            UPDATE adoption
            SET status='adopted'
            WHERE id=?
        """, (adoption_id,))

        title = "Adoption Approved"
        message = "🎉 Your adoption request has been approved!"

    else:
        title = "Adoption Rejected"
        message = "❌ Your adoption request was rejected."
    
    # INSERT NOTIFICATION (FIXED VERSION)
    cur.execute("""
    INSERT INTO notifications (username, title, message, type, reference_id)
    VALUES (?, ?, ?, ?, ?)
""", (
    username,
    title,
    message,
    "adoption_status",
    adoption_id
))

    conn.commit()
    conn.close()

    return jsonify({"message": "Request updated and user notified"})

@app.route("/adoptions/<int:id>", methods=["PUT"])
def update_adoption_status(id):

    data = request.json
    status = data.get("status")

    conn = get_db()
    cur = conn.cursor()

    cur.execute("""
        UPDATE adoption
        SET status=?
        WHERE id=?
    """, (status, id))

    conn.commit()
    conn.close()

    return jsonify({"message": "Status updated"})
    
@app.route("/adoptions/<int:id>", methods=["DELETE"])
def delete_adoption(id):

    conn = get_db()
    cur = conn.cursor()

    cur.execute("DELETE FROM adoption WHERE id=?", (id,))

    conn.commit()
    conn.close()

    return jsonify({"message": "Listing removed"})
# =====================================================
# GET UNREAD NOTIFICATION COUNT
# =====================================================
@app.route("/notifications/unread_count/<username>", methods=["GET"])
def unread_count(username):

    conn = get_db()
    cur = conn.cursor()

    row = cur.execute("""
        SELECT COUNT(*) FROM notifications
        WHERE username=? AND is_read=0
    """, (username,)).fetchone()

    conn.close()

    return jsonify({"count": row[0]})

# =====================================================
# REGISTER
# =====================================================
@app.route("/register", methods=["POST"])
def register():

    data = request.json
    username = data.get("username")
    password = data.get("password")
    
    # Hash the password securely using Bcrypt
    hashed_pw = bcrypt.generate_password_hash(password).decode('utf-8')

    conn = get_db()
    cur = conn.cursor()

    try:
        cur.execute("""
            INSERT INTO users (username, password, role)
            VALUES (?, ?, 'user')
        """, (username, hashed_pw))

        conn.commit()
        conn.close()

        return jsonify({"message": "User registered successfully"})

    except:
        conn.close()
        return jsonify({"error": "Username already exists"}), 400

# =====================================================
# LOGIN
# =====================================================
@app.route("/login", methods=["POST"])
def login():

    data     = request.json
    username = data.get("username")
    password = data.get("password")

    conn = get_db()
    cur  = conn.cursor()

    # Get the user by username ONLY
    user = cur.execute("""
        SELECT * FROM users
        WHERE username=?
    """, (username,)).fetchone()

    conn.close()

    # Verify the securely hashed password with fallback for plain text (fixes Invalid Salt crash)
    is_valid = False
    if user:
        try:
            is_valid = bcrypt.check_password_hash(user["password"], password)
        except (ValueError, Exception):
            # Fallback if password in DB is plain text or has an invalid salt
            is_valid = (user["password"] == password)

    if user and is_valid:
        return jsonify({
            "message":    "Login success",
            "role":       user["role"],
            "id":         user["id"],
            "shelter_id": user["shelter_id"],   # None for super-admin / vet
        })
    else:
        return jsonify({"error": "Invalid credentials"}), 401
    
@app.route('/notifications/<username>', methods=['GET'])
def get_notifications(username):
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, title, message, is_read, created_at, type, reference_id
        FROM notifications
        WHERE username = ?
        ORDER BY created_at DESC
    """, (username,))

    rows = cursor.fetchall()
    conn.close()

    notifications = []
    for row in rows:
        notifications.append({
            "id": row[0],
            "title": row[1],
            "message": row[2],
            "is_read": row[3],
            "created_at": row[4],
            "type": row[5],
            "reference_id": row[6]
        })

    return jsonify(notifications)
@app.route('/notifications/read/<int:notification_id>', methods=['PUT'])
def mark_notification_read(notification_id):
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute(
        "UPDATE notifications SET is_read = 1 WHERE id = ?",
        (notification_id,)
    )

    conn.commit()
    conn.close()

    return jsonify({"message": "Marked as read"})
@app.route("/notifications/<int:id>", methods=["DELETE"])
def delete_notification(id):

    conn = get_db()
    cur = conn.cursor()

    cur.execute("DELETE FROM notifications WHERE id=?", (id,))
    conn.commit()
    conn.close()

    return jsonify({"message": "Notification deleted"})
# =====================================================
# START
# =====================================================
if __name__ == "__main__":

    print("Server starting...")

    app.run(
        host="0.0.0.0",  # Allow access from all local network IPs
        port=5000,
        debug=True,
        use_reloader=False  # Disable reloader to fix WinError 10038 on Windows
    )
