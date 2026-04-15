FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY simulators.py .

EXPOSE 5020 8084 8085

CMD ["python", "-u", "simulators.py"]
