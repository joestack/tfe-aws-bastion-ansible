# tfe-aws-bastion-ansible

The purpose of this repo is to dynamically create an Ansible inventory file based on Terraform (IaC).

While Ansible is very good in doing its job in the realm of Configuration Management (CM),
Terraform is the world most widely used Infrastructure as Code (IaC) provisioning tool.

Combining both tools (IaC and CM) together enables you to achieve super-power by running declarative (operating) system configuration
on top of any declarative described infrastructure.

In other words: None of those tools are meant to substitute the other. They work perfectly hand-in-hand together.     

## Use-Case of this AWS deployment:

* We have web-nodes within private subnets that are not accessible form public internet
  * we can scale out/in the amount of web-nodes
  * the assignment of an ip address is dynamic (so we don't know them upfront and we don't care :)
* We have a public facing loadbalancer to route traffic
  * the loadbalancer distributes the web traffic from the public facing side to the private web-nodes  
* We have a public facing bastion host that is able to connect to the private web-nodes
  * the bastion host is used to run the ansible playbook 
  * introducing a bastion host ensures that the entire workflow is abstracted
  * and to get rid of the "it worked on my laptop" situation

    
