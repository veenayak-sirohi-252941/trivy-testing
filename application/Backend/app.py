from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
import requests
import os
from dotenv import load_dotenv

# 1. Load your local .env file variables into environment context
load_dotenv()

class Config:
    # 2. Extract values dynamically from environment variables
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY')
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # 3. Fail fast if crucial secrets are missing in production
    if not JWT_SECRET_KEY:
        raise ValueError("CRITICAL SECURITY ERROR: No JWT_SECRET_KEY set in the environment!")
    if not SQLALCHEMY_DATABASE_URI:
        raise ValueError("CRITICAL SECURITY ERROR: No DATABASE_URL set in the environment!")

app = Flask(__name__)
CORS(app)

# 4. Bind configuration options from our secure Config class
app.config.from_object(Config)

# Initialize Extensions
db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)

POKEAPI_URL = "https://pokeapi.co/api/v2/pokemon"
POKEMON_LIST_CACHE = []

# ==========================================
# DATABASE MODEL
# ==========================================
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    
    squad = db.relationship('TeamMember', backref='user', lazy=True, cascade="all, delete-orphan")

class TeamMember(db.Model):
    __tablename__ = 'team_members'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    pokemon_id = db.Column(db.Integer, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    sprite = db.Column(db.String(255), nullable=False)

# Create tables within the database context
with app.app_context():
    db.create_all()

# ==========================================
# AUTHENTICATION ROUTES
# ==========================================

@app.route('/api/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username', '').strip()
    password = data.get('password', '')

    if not username or not password:
        return jsonify({"error": "Username and password are required"}), 400

    existing_user = User.query.filter_by(username=username).first()
    if existing_user:
        return jsonify({"error": "Username is already taken"}), 400

    hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
    new_user = User(username=username, password_hash=hashed_password)
    
    try:
        db.session.add(new_user)
        db.session.commit()
        return jsonify({"message": "User registered successfully!"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": "Database error occurred"}), 500

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username', '').strip()
    password = data.get('password', '')

    user = User.query.filter_by(username=username).first()
    if not user or not bcrypt.check_password_hash(user.password_hash, password):
        return jsonify({"error": "Invalid username or password"}), 401

    access_token = create_access_token(identity=str(user.id))
    return jsonify({
        "token": access_token,
        "username": user.username
    }), 200



# ==========================================
# DAST TESTING ROUTES
# ==========================================
@app.route('/api/zap-canary', methods=['GET'])
def zap_canary():
    # TEMPORARY: intentional reflected XSS for DAST verification.
   
    q = request.args.get('q', '')
    return f"<html><body>Search results for: {q}</body></html>"


# ==========================================
# EXISTING POKEMON ROUTES
# ==========================================
@app.route('/api/pokemon', methods=['GET'])
def get_all_pokemon():
    global POKEMON_LIST_CACHE
    try:
        if not POKEMON_LIST_CACHE:
            response = requests.get(f"{POKEAPI_URL}?limit=151")
            response.raise_for_status()
            data = response.json()
            detailed_list = []
            for index, entry in enumerate(data["results"], start=1):
                detailed_list.append({
                    "id": index,
                    "name": entry["name"].capitalize(),
                    "sprite": f"https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/{index}.png"
                })
                POKEMON_LIST_CACHE = detailed_list
        return jsonify(POKEMON_LIST_CACHE)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/pokemon/stats/<int:poke_id>', methods=['GET'])
def get_pokemon_stats(poke_id):
    try:
        response = requests.get(f"{POKEAPI_URL}/{poke_id}")
        if response.status_code == 404:
            return jsonify({"error": "Pokemon not found"}), 404
        response.raise_for_status()
        data = response.json()

        description = "No description available."
        try:
            species_response = requests.get(f"https://pokeapi.co/api/v2/pokemon-species/{poke_id}")
            if species_response.status_code == 200:
                species_data = species_response.json()
                for entry in species_data.get("flavor_text_entries", []):
                    if entry["language"]["name"] == "en":
                        description = entry["flavor_text"].replace("\n", " ").replace("\f", " ")
                        break
        except Exception as e:
            print(f"Error fetching description: {e}")

        ability = data["abilities"][0]["ability"]["name"].replace("-", " ").title()
        
        move_details = []
        for move in data["moves"][:4]:
            move_response = requests.get(move["move"]["url"])
            if move_response.status_code == 200:
                move_data = move_response.json()
                move_details.append({
                    "name": move_data["name"].replace("-", " ").title(),
                    "type": move_data["type"]["name"]
                })

        stats_data = {
            "types": [t["type"]["name"] for t in data["types"]],
            "ability": ability,
            "moves": move_details,
            "description": description,
            "stats": {s["stat"]["name"]: s["base_stat"] for s in data["stats"]},
            "height": data["height"] / 10,
            "weight": data["weight"] / 10
        }
        return jsonify(stats_data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    
@app.route('/api/squad', methods=['GET'])
@jwt_required()
def get_squad():
    current_user_id = int(get_jwt_identity())
    user = User.query.get(current_user_id)
    
    if not user:
        return jsonify({"error": "User not found"}), 404
        
    squad_data = [{
        "id": member.pokemon_id,
        "name": member.name,
        "sprite": member.sprite
    } for member in user.squad]
    
    return jsonify(squad_data), 200

@app.route('/api/squad/sync', methods=['POST'])
@jwt_required()
def sync_squad():
    current_user_id = int(get_jwt_identity())
    incoming_team = request.get_json()

    if not isinstance(incoming_team, list):
        return jsonify({"error": "Invalid payload format. Expected list."}), 400
        
    if len(incoming_team) > 5:
        return jsonify({"error": "Squad size limit exceeded (max 5)."}), 400

    try:
        TeamMember.query.filter_by(user_id=current_user_id).delete()

        for poke in incoming_team:
            member = TeamMember(
                user_id=current_user_id,
                pokemon_id=poke['id'],
                name=poke['name'],
                sprite=poke['sprite']
            )
            db.session.add(member)
            
        db.session.commit()
        return jsonify({"message": "Squad state synced successfully"}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"Failed syncing data: {str(e)}"}), 500    

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)