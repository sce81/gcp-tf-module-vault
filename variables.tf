variable "name"                                       {default = "vault"}
variable "project"                                    {}
variable "network"                                    {}
variable "subnetwork_name"                            {}
variable "backend_location"                           {}
variable "service_account_email"                      {}
variable "vault_image"                                {}
variable "user_data"                                  {}
variable "cluster_description"                        {}


variable "create_public"                              {default = 0}
variable "create_private"                             {default = 1}
variable "region"                                     {default = "europe-west1"}
variable "cluster_name"                               {default = "vault-cluster"}
variable "machine_type"                               {default = "n1-highcpu-2"}
variable "nat_ip"                                     {default = "null"}
variable "create_service_account"                     {default = 1}
variable "storage_class"                              {default = "REGIONAL"}
variable "bucket_acl"                                 {default = "projectPrivate"}
variable "enable_web_proxy"                           {default = 0}
variable "use_external_service_account"               {default = 0}
variable "instance_group_target_pools"                {default = "null"}
variable "cluster_tag_name"                           {default = "vault"}
variable "cluster_size"                               {default = 3}
variable "count_public_ip"                            {default = 1}
variable "templateversion"                            {default = 0}
variable "bucket_force_destroy"                       {default = false}
variable "service_account_scopes"                     {type = list(string)}
variable "inbound_api_cidr"                           {type = list(string)}
variable "metadata_key_name_for_cluster_size"         {default = "cluster-size"}
variable "cluster_port"                               {default = 8201}
variable "api_port"                                   {default = 8200}
variable "health_check_port"                          {default = 8080}
variable "root_disk_size"                             {default = 30}
variable "root_disk_type"                             {default = "pd-standard"}
variable "use_external_account"                       {default = 0}
variable "service_account_enabled"                    {default = 1}
variable "external_account_enabled"                   {default = 0}
variable "instance_group_update_strategy"             {default = "NONE"}
variable "custom_tags"                                {type = list(string)}
variable "custom_metadata" {
  type    = map(string)
  default = {}
}
variable "lb_ingress_ips"                             {type = list(string)}
#variable forwarding_rule_ip_address             type                            ="list}
variable "lb_health_check_interval_sec"               {default = 10}
variable "lb_health_check_timeout_sec"                {default = 10}
variable "lb_health_check_healthy_threshold"          {default = 1}
variable "lb_health_check_unhealthy_threshold"        {default = 5}
variable "lb_health_check_port"                       {default = 8000}
variable "lb_health_check_path"                       {default = "/"}
variable "target_pool_session_affinity"               {default = "CLIENT_IP"}
