import flask as Flask
import hashlib as HashLib

Secret = "SuperSecretKey"

Accounts = {
    "Admin": "Password123",
}

App = Flask.Flask(
    import_name = __name__,
)

def BuildSignature(Username: str, Password: str, Body: dict) -> str:
    # Create a signature using the provided credentials and the secret key
    Signature = HashLib.sha256(f"{Username}:{Password}:{Secret}:{Flask.json.dumps(Body).replace(' ', '')}".encode()).hexdigest()
    return Signature

@App.route("/login", methods = ["POST"])
def Index():
    # Get the credentials from the request
    Username = Flask.request.get_json().get("Username")
    Password = Flask.request.get_json().get("Password")

    # Verify that the credentials are provided
    if (not Username or not Password):
        return Flask.jsonify({
            "Success": False,
            "Message": "Missing credentials",
        }), 400

    # Verify the credentials against the stored accounts
    if (Accounts.get(Username) == Password):
        Body = {
            "Success": True,
            "Message": "Login successful",
        }

        # Build the response with the signature
        return Flask.jsonify({
            **Body,
            "Signature": BuildSignature(Username, Password, Body),
        }), 200
    else:
        Body = {
            "Success": False,
            "Message": "Invalid credentials",
        }

        # Build the response with the signature
        return Flask.jsonify({
            **Body,
            "Signature": BuildSignature(Username, Password, Body),
        }), 401

# Run the application
if __name__ == "__main__":
    App.run(host = "0.0.0.0", port = 8080)