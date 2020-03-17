# tfe-aws-bastion-ansible
The purpose of this repo is to dynamically create an Ansible inventory file based on Terraform (IaC).
While Ansible is very good in doing its job in the realm of Configuration Management (CM),
Terraform is the worlds most widely used Infrastructure as Code (IaC) provisioning tool.
Combining both tools (IaC and CM) together enables you to achieve super-power by running declarative (operating) system configuration
on top of any declarative described infrastructure.
In other words: None of those tools are meant to substitute the other. They work perfectly hand-in-hand together.
## Use-Case of this AWS deployment:
* We have web-nodes within private subnets that are not accessible from the public internet.
  * We can scale out/in the amount of web-nodes.
  * The assignment of an ip address is dynamic, so we don't know them upfront and we don't care.
* We have a public facing loadbalancer to route traffic.
  * The loadbalancer distributes the web traffic from the public facing side to the private web-node.
* We have a public facing bastion host that is able to connect to the private web-nodes.
  * The bastion host is used to run the ansible playbook.
  * Introducing a bastion host ensures that the entire workflow is abstracted into the bastion.
  * This removes the "it worked on my laptop" situation.