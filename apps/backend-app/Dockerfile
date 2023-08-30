FROM registry.fedoraproject.org/fedora-minimal

EXPOSE 8080

RUN microdnf -y install python-pip && microdnf clean all
RUN pip install starlette uvicorn

USER 1001

COPY python /app/python

WORKDIR /app

CMD ["python", "python/main.py"]
