## dynamically generate a `inventory` file for Ansible Configuration Automation 

##
## here we create the list of available WEB nodes
## to be used as input for the GROUPS template
##
data "template_file" "ansible_web_hosts" {
  count      = var.web_node_count
  template   = file("${path.module}/templates/ansible_hosts.tpl")
  depends_on = [aws_instance.web_nodes]

  vars = {
    node_name    = aws_instance.web_nodes.*.tags[count.index]["Name"]
    ansible_user = var.ssh_user
    extra        = "ansible_host=${element(aws_instance.web_nodes.*.private_ip, count.index)}"
  }
}

##
## here we assign the WEB-NODES to the right GROUP
## 
data "template_file" "ansible_groups" {
  template = file("${path.module}/templates/ansible_groups.tpl")

  vars = {
    #jump_host_ip  = "${aws_instance.jumphost.public_ip}"
    #ssh_user_name = "${var.ssh_user}"
    web_hosts_def = join("", data.template_file.ansible_web_hosts.*.rendered)
  }
}

##
## here we write the rendered "ansible_groups" template into a local file
## on the Terraform exec environment (the shell where the terraform binary runs)
##
resource "local_file" "ansible_inventory" {
  depends_on = [data.template_file.ansible_groups]

  content  = data.template_file.ansible_groups.rendered
  filename = "${path.module}/inventory"
}

##
## here we copy the local file to the jumphost
## using a "null_resource" to be able to trigger a file provisioner
##
resource "null_resource" "provisioner" {
  depends_on = [local_file.ansible_inventory]

  triggers = {
    always_run = timestamp()
  }

  provisioner "file" {
    source      = "${path.module}/inventory"
    destination = "~/inventory"

    connection {
      type        = "ssh"
      host        = aws_instance.jumphost.public_ip
      user        = var.ssh_user
      private_key = var.id_rsa_aws
      insecure    = true
    }
  }
}

resource "null_resource" "cp_ansible" {
  depends_on = [null_resource.provisioner]

  triggers = {
    always_run = timestamp()
  }

  provisioner "file" {
    source      = "${path.module}/ansible"
    destination = "~/"

    connection {
      type        = "ssh"
      host        = aws_instance.jumphost.public_ip
      user        = var.ssh_user
      private_key = var.id_rsa_aws
      insecure    = true
    }
  }
}

resource "null_resource" "ansible_run" {
  depends_on = [
    null_resource.cp_ansible,
    local_file.ansible_inventory,
    aws_instance.web_nodes,
    aws_route53_record.jumphost
  ]

  triggers = {
    always_run = timestamp()
  }

  connection {
    type        = "ssh"
    host        = aws_instance.jumphost.public_ip
    user        = var.ssh_user
    private_key = var.id_rsa_aws
    insecure    = true
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 30 && ansible-playbook -i ~/inventory ~/ansible/playbook.yml ",
    ]
  }
}

