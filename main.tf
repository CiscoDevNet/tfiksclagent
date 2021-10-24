
data "terraform_remote_state" "global" {
  backend = "remote"
  config = {
    organization = var.org
    workspaces = {
      name = var.globalwsname
    }
  }
}

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

data "terraform_remote_state" "host" {
  backend = "remote"
  config = {
    organization = var.org
    workspaces = {
      name = var.hostwsname
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
variable "hostwsname" {
  type = string
}
variable "globalwsname" {
  type = string
}


resource "null_resource" "web" {
  provisioner "remote-exec" {
    inline = [
        "docker login containers.cisco.com -u ${local.dockeruser} -p ${local.dockerpass}",
    ]
    connection {
      type = "ssh"
      host = local.host
      user = "iksadmin"
      private_key = local.private_key
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
    value = local.url 
  }
  set {
    name  = "controllerInfo.account"
    value = local.account
  }
  set {
    name  = "controllerInfo.username"
    value = local.username
  }
  set {
    name  = "controllerInfo.password"
    value = local.password
  }
  set {
    name  = "controllerInfo.accessKey"
    value = base64decode(data.kubernetes_secret.access.binary_data["accesskey"])
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
    value = local.storename
    # value = "IKSChaiStore"
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
  host = data.terraform_remote_state.host.outputs.host
  privatekey = data.terraform_remote_state.global.outputs.privatekey
  url = data.terraform_remote_state.global.outputs.url
  account = data.terraform_remote_state.global.outputs.account
  namespaces = data.terraform_remote_state.global.outputs.namespaces
  username = data.terraform_remote_state.global.outputs.username
  password = data.terraform_remote_state.global.outputs.password
  dockeruser = data.terraform_remote_state.global.outputs.dockeruser
  dockerpass = data.terraform_remote_state.global.outputs.dockerpass
  storename = data.terraform_remote_state.global.outputs.storename
}

