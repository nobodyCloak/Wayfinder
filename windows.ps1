# curl from https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.5.1-windows-x86.zip for 32-bit
# https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.5.1-windows-x86_64.zip for 64-bit

extract to C:\Program Files
rename filebeat-<version>-windows to Filebeat

cd 'C:\Program Files\Filebeat'
.\install-service-filebeat.ps1