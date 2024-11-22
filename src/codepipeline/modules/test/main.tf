module "codepipeline_label" {
  source = "../codepipeline_label"
  attributes = ["codepipeline"]
}

output "id" {
  value = module.codepipeline_label.id
}
