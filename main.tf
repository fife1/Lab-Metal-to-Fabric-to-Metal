terraform {
  required_providers {
    equinix = {
      source  = "equinix/equinix"
      version = "2.6.0"
    }
  }
}

provider "equinix" {
  # Configuration options 
  # Credentials for only Equinix Metal resources 
  auth_token = "my_api_token"

  client_id = "my_client_id"

  client_secret = "my_client_secret"

}

resource "equinix_metal_vlan" "vlan1" {
  project_id = var.metal_project_id
  metro      = var.metro1
  vxlan  = var.vxlan
}

resource "equinix_metal_device" "metal_test1" {
  hostname         = "test1"
  plan             = var.plan
  metro            = var.metro1
  operating_system = var.operating_system
  billing_cycle    = "hourly"
  project_id       = var.metal_project_id
  user_data = format("#!/bin/bash\napt update\napt install vlan\nmodprobe 8021q\necho '8021q' >> /etc/modules-load.d/networking.conf\nip link add link bond0 name bond0.%g type vlan id %g\nip addr add 192.168.100.1/24 brd 192.168.100.255 dev bond0.%g\nip link set dev bond0.%g up", equinix_metal_vlan.vlan1.vxlan, equinix_metal_vlan.vlan1.vxlan, equinix_metal_vlan.vlan1.vxlan, equinix_metal_vlan.vlan1.vxlan)
}

resource "equinix_metal_device_network_type" "port_type_test1" {
  device_id = equinix_metal_device.metal_test1.id
  type      = "hybrid-bonded"
}
resource "equinix_metal_port_vlan_attachment" "vlan_attach_test1" {
  device_id = equinix_metal_device_network_type.port_type_test1.id
  port_name = "bond0"  
  vlan_vnid = equinix_metal_vlan.vlan1.vxlan 
}

resource "equinix_metal_vlan" "vlan2" {
  metro      = var.metro2
  project_id  = var.metal_project_id
  vxlan       = var.vxlan
}

resource "equinix_metal_device" "metal_test2" {
  hostname         = "test2"
  plan             = var.plan
  metro            =  var.metro2
  operating_system =  var.operating_system
  billing_cycle    = "hourly"
  project_id       = var.metal_project_id
   user_data = format("#!/bin/bash\napt update\napt install vlan\nmodprobe 8021q\necho '8021q' >> /etc/modules-load.d/networking.conf\nip link add link bond0 name bond0.%g type vlan id %g\nip addr add 192.168.100.2/24 brd 192.168.100.255 dev bond0.%g\nip link set dev bond0.%g up", equinix_metal_vlan.vlan2.vxlan, equinix_metal_vlan.vlan2.vxlan, equinix_metal_vlan.vlan2.vxlan,equinix_metal_vlan.vlan2.vxlan)
}

resource "equinix_metal_device_network_type" "port_type_test2" {
  device_id = equinix_metal_device.metal_test2.id
  type      = "hybrid-bonded"
}

resource "equinix_metal_port_vlan_attachment" "vlan_attach_test2" {
  device_id = equinix_metal_device_network_type.port_type_test2.id
  port_name = "bond0"
  vlan_vnid = equinix_metal_vlan.vlan2.vxlan
}

## Create VC via dedciated port in metro1
/* this is the "Interconnection ID" of the "DA-Metal-to-Fabric-Dedicated-Redundant-Port" via Metal's portal*/
data "equinix_metal_connection" "metro1_port" {
  connection_id = var.conn_id
}

resource "equinix_metal_virtual_circuit" "metro1_vc" {
  connection_id = var.conn_id
  project_id    = var.metal_project_id
  port_id       = data.equinix_metal_connection.metro1_port.ports[0].id
  vlan_id       = equinix_metal_vlan.vlan1.vxlan
  nni_vlan      = equinix_metal_vlan.vlan1.vxlan
  name          = "fnawaz-tf-vc"
}
## Request a Metal connection and get a z-side token from Metal
resource "equinix_metal_connection" "example" {
  name               = "faiq-tf-metal-port"
  project_id         = var.metal_project_id
  type               = "shared"
  redundancy         = "primary"
  metro              = var.metro2
  speed              = "10Gbps"
  service_token_type = "z_side"
  contact_email      = "fnawaz@equinix.com"
  vlans              = [equinix_metal_vlan.vlan2.vxlan]
}

## Use the token from "equinix_metal_connectio.example" to setup VC in fabric portal:
 /* A-side port is  your Metal owned dedicated port in Equinix Fabric portal */

resource "equinix_fabric_connection" "this" {
  name = "tf-metalport-fabric"
  type = "EVPL_VC"
  bandwidth = 50
  notifications {
    type   = "ALL"
    emails = ["fnawaz@equinix.com"]
  }
  order {
    purchase_order_number = ""
  }
  a_side {
    access_point {
      type = "COLO"
      port {
        uuid = var.aside_port
      }
      link_protocol {
        type     = "DOT1Q"
        vlan_tag = equinix_metal_vlan.vlan1.vxlan
      }
      location {
        metro_code  = var.metro1
      }
    }
  }
  z_side {
    service_token {
      uuid = equinix_metal_connection.example.service_tokens.0.id
    }
  }
}
