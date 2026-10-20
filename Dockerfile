FROM hshar/webapp

WORKDIR /var/www/html

COPY . /var/www/html/

CMD ["sh", "-c", "rm -f /run/apache2/apache2.pid && exec apachectl -D FOREGROUND"]
