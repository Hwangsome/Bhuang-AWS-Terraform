variable "alarm_configuration" {
  type = object({
    alarms                    = list(string)
    ignore_poll_alarm_failure = bool
  })
  default     = null
  description = <<-DOC
     Configuration of deployment to stop when a CloudWatch alarm detects that a metric has fallen below or exceeded a defined threshold.
      alarms:
        A list of alarms configured for the deployment group.
      ignore_poll_alarm_failure:
        Indicates whether a deployment should continue if information about the current state of alarms cannot be retrieved from CloudWatch.
  DOC
}