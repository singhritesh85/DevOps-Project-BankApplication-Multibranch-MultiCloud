To create Application Gateway Ingress Controller make sure the Managed Identity **ingressapplicationgateway-aks-cluster** sholud have below accesses
```
(a) At least Reader access for the resource group in which Application Ingress Controller exists.
(b) Contributor access for the Application Ingress Controller.
```
<br> <br/>
![image](https://github.com/singhritesh85/terraform-azure/assets/56765895/7380c694-81bd-43dd-83be-61c45d952783)
<br> <br/> <br> <br/>
**In this terraform script it has been achieved using as written below**
<br> <br/>
![image](https://github.com/singhritesh85/terraform-azure/assets/56765895/1f158295-c45b-4663-b081-1922b199881b)

<br><br/>
Please provide the information in the terraform script as wriiten below
1. Use your own .pfx extension file of your SSL Certificate in main directory and provide it's password in file module/application-gateway.tf.
2. Provide public SSH key in the files custom_data_devopsagent.sh, custom_data_blackboxexporter.sh, custom_data_grafana.sh, custom_data_loki.sh and custom_data_prometheus.sh.
3. Provide tenant id and subscription id in the file provider.tf.
4. Provide subscription id in the file backend.tf. 
