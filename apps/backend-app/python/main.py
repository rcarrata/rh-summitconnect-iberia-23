import argparse
import os
import uvicorn

from thingid import generate_thing_id
from starlette.applications import Starlette
from starlette.responses import JSONResponse, Response

name = generate_thing_id().replace("-", " ").title()
pod = os.environ.get("HOSTNAME", "backend")
star = Starlette(debug=True)

@star.route("/api/hello", methods=["GET", "POST"])
async def hello(request):
    if request.method == "GET":
        return Response(f"Hola!. Yo soy {name} ({pod}).\n", 200)

    request_data = await request.json()
    requestor = request_data["name"]

    response_data = {
        "text": f"Hola, {requestor}.  Yo soy {name} ({pod}).",
        "name": name,
    }

    return JSONResponse(response_data)

@star.route("/api/health", methods=["GET"])
async def health(request):
    return Response("OK\n", 200)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)

    args = parser.parse_args()

    uvicorn.run(star, host=args.host, port=args.port)
