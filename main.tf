
#Helm install of sample app on IKS
data "terraform_remote_state" "iksws" {
  backend = "remote"
  config = {
    organization = var.org
    workspaces = {
      name = var.ikswsname
    }
  }
}

provider "kubernetes" {
    host = local.kube_config.clusters[0].cluster.server
    client_certificate = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key = base64decode(local.kube_config.users[0].user.client-key-data)
    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
}

variable "org" {
  type = string
}
variable "ikswsname" {
  type = string
}
variable "url" {
  type = string
}
variable "account" {
  type = string
}
variable "username" {
  type = string
}
variable "password" {
  type = string
}
variable "accessKey" {
  type = string
}
variable "namespaces" {
  type = string 
}
variable "dockeruser" {
  type = string 
}
variable "dockerpass" {
  type = string 
}
variable "private_key" {
  type = string 
}


resource "null_resource" "web" {
  provisioner "remote-exec" {
    inline = [
        "docker login containers.cisco.com -u ${var.dockeruser} -p ${var.dockerpass}",
    ]
    connection {
      type = "ssh"
      host = local.kube_config.clusters[0].cluster.server 
      user = "iksadmin"
      private_key = var.private_key
      port = "22"
      agent = false
    }
  }

}


resource "kubernetes_namespace" "appd" {
  metadata {
    name = "appdynamics"
  }
}

data "kubernetes_secret" "access" {
  metadata {
    name = "accesssecret"
    namespace = "default"
  }
  binary_data = {
    "accesskey" = ""

  }
}

resource helm_release appdiksfrtfcb {
  name       = "appdcluster"
  namespace = kubernetes_namespace.appd.metadata.0.name
  chart = "https://prathjan.github.io/helm-chart/cluster-agent-0.1.18.tgz"

  set {
    name  = "controllerInfo.url"
    value = var.url 
  }
  set {
    name  = "controllerInfo.account"
    value = var.account
  }
  set {
    name  = "controllerInfo.username"
    value = var.username
  }
  set {
    name  = "controllerInfo.password"
    value = var.password
  }
  set {
    name  = "controllerInfo.accessKey"
    # value = var.accessKey
    value = "${data.kubernetes_secret.access.binary_data["accesskey"]}"
  }
  set {
    name  = "clusterAgent.nsToMonitorRegex"
    value = ".*"
    # value = "{ default,appdynamics }"
  }
  set {
    name  = "install.metrics-server"
    value = "false"
  }
#  set {
#    name  = "instrumentationConfig.imageInfo.java.image"
#    value = "docker.io/appdynamics/java-agent:21.3.0"
#  }
#  set {
#    name  = "instrumentationConfig.imageInfo.java.agentMountPath"
#    value = "/opt/appdynamics"
#  }
#  set {
#    name  = "instrumentationConfig.imageInfo.java.imagePullPolicy"
#    value = "Always"
#  }
#  set {
#    name  = "instrumentationConfig.enabled"
#    value = "true"
#  }
#  set {
#    name  = "instrumentationConfig.instrumentationMethod"
#    value = "Env"
#  }
#  set {
#    name  = "instrumentationConfig.nsToInstrumentRegex"
#    value = "default"
#  }
  set {
    name  = "instrumentationConfig.defaultAppName"
    value = "IKSChaiStore"
  }
#  set {
#    name  = "instrumentationConfig.appNameStrategy"
#    value = "namespace"
#  }
#  set {
#    name  = "instrumentationConfig.instrumentationRules.namespaceRegex"
#    value = "[ default ]"
#  }
#  set {
#    name  = "instrumentationConfig.instrumentationRules.language"
#    value = "java"
#  }
#  set {
#    name  = "logProperties.logLevel"
#    value = "DEBUG"
#  }
}

output "access" {
  value = "${data.kubernetes_secret.access.binary_data["accesskey"]}" 
}

provider "helm" {
  kubernetes {
    host = local.kube_config.clusters[0].cluster.server
    client_certificate = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key = base64decode(local.kube_config.users[0].user.client-key-data)
    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
  }
}

locals {
  kube_config = yamldecode(data.terraform_remote_state.iksws.outputs.kube_config)
  kube_config_str = data.terraform_remote_state.iksws.outputs.kube_config
}

