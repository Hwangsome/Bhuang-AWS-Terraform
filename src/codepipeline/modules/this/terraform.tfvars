#context = {
#  enabled             = true
#  namespace           = "dev"
#  tenant              = "teamA"
#  environment         = "staging"
#  stage               = "pre-prod"
#  name                = "app-service"
#  delimiter           = "-"
#  attributes          = ["frontend", "api"]
#  tags                = {
#    Owner = "teamA"
#    Project = "AppModernization"
#  }
#  additional_tag_map  = {
#    CostCenter = "12345"
#  }
#  regex_replace_chars = "/[^a-zA-Z0-9-]/"
#  label_order         = ["namespace", "tenant", "stage", "name", "attributes"]
#  id_length_limit     = 63
#  label_key_case      = "lower"
#  label_value_case    = "lower"
#}
