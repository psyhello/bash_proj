#! bin/bash


PASS=` base64 /dev/urandom | head -10 | tr -d -c 'a-z''0-9''A-Z' | cut -c1-12`




echo "Hi! Let's begin instalation. First.Please give a name for your container.Or you can leave it blanck and i give it a name of demo#"

read containername

if [[ -n $containername ]]; then
	CONTNAME="$containername"
else
	CONTNAME="demo$RANDOM"
	echo "Container name is $CONTNAME. Please remember it"
fi

mkdir -p $CONTNAME

cd $CONTNAME

echo "What branch of HRCRM i need to install? For Master branch leave it blanck"

read version

git clone -b $version http://jenkins:hf7T45Tf43s@gitlab.talentforce.ru/hrcrm/hrcrm.git lamp-docroot

cd lamp-docroot

mkdir -p  tmp

cd tmp

git clone -b demodata http://jenkins:hf7T45Tf43s@gitlab.talentforce.ru/hrcrm/model-tf-db.git db

cd db

echo "CREATE USER 'docker'@'%' IDENTIFIED BY '$PASS';GRANT ALL PRIVILEGES ON *.* TO 'docker'@'%';FLUSH PRIVILEGES;" >> pass.sql

cd ../
cd ../
cd ../

cp -R /docker_containers/demofiles/upload/ $PWD/lamp-docroot/


git clone -b nonhttps https://github.com/SidorkinAlex/lamp-ubuntu18.04.git configs

cd configs

rm -r *.*

cd ../

sudo chmod -R 777 lamp-docroot/
sudo chmod -R 777 $PWD/configs/lamp-mariadb $PWD/lamp-docroot $PWD/configs/lamp-apache-conf
sudo chmod -R 777 $PWD/configs/lamp-mariadb-conf/debian-start

echo "Nice! Now its time for ports settings.You can leave it blanck to use defaults."

echo "First.What Http port you want to use? "

read httpport

echo "Okay, now https port please"

read httpsport

echo "Okay, DB port now."

read dbport

echo "Finaly, ssh-port"

read sshport

echo "Thank you. Building"




if [[ -n $httpport ]]; then
    PORTHTTPFORDOCKER="-p $httpport:80"
    ufw allow $httpport
else
    PORTHTTPFORDOCKER="-p 80:80 "
    ufw allow 80
fi

if [[ -n $httpsport ]]; then
	PORTHTTPSFORDOCKER="-p $httpsport:443"
	ufw allow $httpsport
else
    PORTHTTPSFORDOCKER="-p 443:443 "
    ufw allow 443
fi

if [[ -n $sshport ]]; then
    PORTSSHFORDOCKER="-p $sshport:22"
    ufw allow $sshport
else
    PORTSSHFORDOCKER="-p 22:22 "
    ufw allow 22
fi


if [[ -n $dbport ]]; then
    DBPORT="-p $dbport:3306"
    ufw allow $dbport
else
    DBPORT="-p 3306:3306 "
    ufw allow 3306
fi


cp -f /docker_containers/demo5/lamp-apache-conf/sites-available/000-default.conf /docker_containers/$CONTNAME/lamp-apache-conf/sites-available/000-default.conf

sed -i 's/demo5/$CONTNAME/' /docker_containers/$CONTNAME/lamp-apache-conf/sites-available/000-default.conf

cd /docker_containers/$CONTNAME/

cp -f /docker_containers/nginx/nginx-main/nginx/conf.d/demo1.conf /docker_containers/nginx/nginx-main/nginx/conf.d/$CONTNAME.conf

sed -i 's/demo1/$CONTNAME/' /docker_containers/nginx/nginx-main/nginx/conf.d/$CONTNAME.conf
sed -i 's/2001/$httpport/' /docker_containers/nginx/nginx-main/nginx/conf.d/$CONTNAME.conf

cp -r .env.example .env 

chmod -R 777 .env

sed -i 's/stage.hr.tsconsulting.com/$CONTNAME.talentforce.ru/' /docker_containers/$CONTNAME/lamp-docroot/.env
sed -i 's/http:\/\/localhost/$CONTNAME.talentforce.ru/' /docker_containers/$CONTNAME/lamp-docroot/.env

touch Dockerfile
echo  "FROM ubuntu:latest 
#Install timezone for openssh and apache configs
ENV TZ=Europe/Moscow
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
#Install tools
RUN apt-get update
RUN apt-get -y install wget \
		nano\
		redis-server\
		systemd\
		curl \
		git \
		php libapache2-mod-php \
		openssh-server \
		apache2 \
		cron \
		software-properties-common dirmngr apt-transport-https
RUN echo \"ServerName localhost\" >> /etc/apache2/apache2.conf
#Install composer
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php
RUN php composer-setup.php --install-dir=/usr/local/bin --filename=composer
#install extinsions for php
RUN apt-get -y install  php-curl   php-common   php-mysql   php-xml   php-zip   php-gd   php-imap   php-ldap php-intl   php-mysqlnd   php-opcache   php-pdo   php-xml   php-calendar   php-ctype   php-curl   php-dom   php-exif   php-fileinfo   php-ftp   php-gd   gettext   php-iconv   php-imap   php-intl   php-json   php-ldap   php-mysqli   php-pdo-mysql   php-phar   php-posix   php-readline   php-shmop   php-simplexml   php-sockets   php-sysvmsg   php-sysvsem   php-sysvshm   php-tokenizer    php-xmlreader   php-xmlwriter   php-xsl   php-zip  php-mbstring
#Install MariaDB
RUN apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc' && add-apt-repository 'deb [arch=amd64,arm64,ppc64el] https://mirror.docker.ru/mariadb/repo/10.5/ubuntu focal main'
RUN apt-get update && apt-get -y install mariadb-server
#Start Redis and apache like a daemon
CMD redis-server --daemonize yes
CMD /usr/sbin/apache2ctl -D FOREGROUND


EXPOSE 80" >> Dockerfile


echo "Okay, all preparations are done. Now i will build and start your container"



docker build -t talentforce:demo .

rm -r Dockerfile

echo "Starting container"

docker run -dit  $PORTHTTPSFORDOCKER $PORTHTTPFORDOCKER $DBPORT $PORTSSHFORDOCKER --name $CONTNAME -v $PWD/configs/lamp-mariadb:/var/lib/mysql -v $PWD/lamp-docroot:/var/www/html -v $PWD/configs/lamp-apache-conf:/etc/apache2 -v $PWD/configs/lamp-mariadb-conf:/etc/mysql talentforce:demo 

echo "setting up a demodata"

docker exec $CONTNAME /bin/bash -c "service apache2 start && service cron start && service mariadb start && redis-server --daemonize yes"
echo "setting up db"
docker exec $CONTNAME bash -c 'cd /var/www/html/tmp/db/; mysql < tf.sql; mysql < pass.sql'
echo "setting up migrations"
docker exec $CONTNAME bash -c 'cd /var/www/html/; composer install --ignore-platform-reqs --no-dev --no-scripts'
docker exec $CONTNAME bash -c 'chmod -R 777 /var/www/html/; cd /var/www/html/; ./vendor/bin/doctrine-migrations migrate --no-interaction; php -f /var/www/html/repair.php sql=true crmid=00000000-0000-0000-0000-000000000001; php  /var/www/html/migration-roleRepair.php; php /var/www/html/migration-modulesHiding.php; chown -R www-data:www-data /var/www/html/; crontab -e -u www-data'
docker exec $CONTNAME bash -c 'cp -r /var/www/html/.env.example /var/www/html/.env ; chmod -R 777 /var/www/html/.env'
docker exec $CONTNAME bash -c 'echo "*    *    *    *    *     cd /var/www/html; php -f cron.php > /dev/null 2>&1" >> /var/spool/cron/crontabs/www-data ; service cron restart'
