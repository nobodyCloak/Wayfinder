#!/bin/bash
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get update
sudo apt-get -y install oracle-java8-installer
wget -q0 - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
sudo apt-get update
sudo apt-get -y install elasticsearch

# sudo vi /etc/elasticsearch/elasticsearch.yml
# need to uncomment line that specifies network.host and replace value with 'localhost'

sudo service elasticsearch restart
# systemctl instead?

sudo update-rc.d elasticsearch defaults 95 10

echo "deb http://packages.elastic.co/kibana/4.5/debian stable main" | sudo tee -a /etc/apt/sources.list.d/kibana-4.5.x.list

sudo apt-get update
sudo apt-get -y install kibana

# sudo vi /opt/kibana/config/kibana.yml
# edit line that specifies server.host and replace it with '"localhost"'
sudo update-rc.d kibana defaults 96 9
sudo service kibana start


sudo apt-get install nginx apache2-utils
sudo htpasswd -c /etc/nginx/htpasswd.users kibanaadmin

# enter password

sudo vi /etc/nginx/sites-available/default
# delete all contents in the file and write the following to the file
<<
server {
    listen 80;

    server_name example.com;

    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/htpasswd.users;

    location / {
        proxy_pass http://localhost:5601;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;        
    }
}
>>

sudo service nginx restart
echo 'deb http://packages.elastic.co/logstash/2.2/debian stable main' | sudo tee /etc/apt/sources.list.d/logstash-2.2.x.list
sudo apt-get update
sudo apt-get install logstash

sudo mkdir -p /etc/pki/tls/certs
sudo mkdir/etc/pki/tls/private

# sudo vi /etc/ssl/openssl.cnf
# after the [ v3_ca ] section, add the following line under it, putting the elk server private ip address
# subjectAltName = IP: 192.168.1.1

cd /etc/pki/tls
sudo openssl req -config /etc/ssl/openssl.cnf -x509 -days 3650 -batch -nodes -newkey rsa:2048 -eyout private/logstash-forwarder.key -out certs/logstash-forwarder.crt

# sudo vi /etc/logstash/conf.d/02-beats-input.conf
# insert the following into the file
<<
input {
  beats {
    port => 5044
    ssl => true
    ssl_certificate => "/etc/pki/tls/certs/logstash-forwarder.crt"
    ssl_key => "/etc/pki/tls/private/logstash-forwarder.key"
  }
}
>>

# sudo vi /etc/logstash/conf.d/10-syslog-filter.conf
# insert the following into the file
<<
filter {
  if [type] == "syslog" {
    grok {
      match => { "message" => "%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}" }
      add_field => [ "received_at", "%{@timestamp}" ]
      add_field => [ "received_from", "%{host}" ]
    }
    syslog_pri { }
    date {
      match => [ "syslog_timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
    }
  }
}
>>

# sudo vi /etc/logstash/conf.d/30-elasticsearch-output.conf
# insert the following into the file
<<
output {
  elasticsearch {
    hosts => ["localhost:9200"]
    sniffing => true
    manage_template => false
    index => "%{[@metadata][beat]}-%{+YYYY.MM.dd}"
    document_type => "%{[@metadata][type]}"
  }
}
>>
sudo service logstash configtest
sudo service logstash restart
sudo update-rc.d logstash defaults 96 9

cd ~
curl -L -O https://download.elastic.co/beats/dashboards/beats-dashboards-1.1.0.zip
sudp apt-get -y install unzip
unzip beats-dashboards-*.zip
cd beats-dashboards-*
./load.sh
cd ~
curl -O https://gist.githubusercontent.com/thisismitch/3429023e8438cc25b86c/raw/d8c479e2a1adcea8b1fe86570e42abab0f10f364/filebeat-index-template.json

curl -XPUT 'http://localhost:9200/_template/filebeat?pretty' -d@filebeat-index-template.json

# scp /etc/pki/tls/certs/logstash-forwarder.crt user@client_server_private_address:/tmp
# copies the generated certs to the client servers. requires password, user, and ip address


