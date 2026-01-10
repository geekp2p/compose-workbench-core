from flask import Flask, jsonify
import os
import socket
from datetime import datetime, timezone

app = Flask(__name__)

@app.get("/")
def root():
    return jsonify({
        "project": "py-hello",
        "language": "python",
        "hostname": socket.gethostname(),
        "time_utc": datetime.now(timezone.utc).isoformat(),
        "note": "If you can see this JSON, Docker networking + port mapping works."
    })

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "5000"))
    app.run(host="0.0.0.0", port=port)
