from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.responses import PlainTextResponse
import subprocess
import tempfile
import os

app = FastAPI()

class CodeInput(BaseModel):
    code: str
    language: str = "C++"

@app.post("/parse")
async def convert_to_srcml(input_data: CodeInput):
    # Create a temporary file to write the source code into
    with tempfile.NamedTemporaryFile(delete=False, suffix=".txt") as tmp:
        tmp.write(input_data.code.encode("utf-8"))
        tmp_path = tmp.name

    try:
        # Run srcml with the temporary file
        result = subprocess.run(
            ["srcml", tmp_path, "--language", input_data.language],
            capture_output=True,
            text=True,
            check=True
        )
        return PlainTextResponse(result.stdout, media_type="application/xml")

    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"srcml error: {e.stderr.strip()}")

    finally:
        os.remove(tmp_path)
