FROM python:2.7.12-alpine
MAINTAINER Antonis Kalipetis <akalipetis@gmail.com>

RUN pip install flask
ADD app.py /opt/flask-hostname/app.py
WORKDIR /opt/flask-hostname
ENV FLASK_APP=app.py
CMD flask run --host=0.0.0.0
