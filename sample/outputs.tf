# Outputs that prove the sample worked.
output "event_bus_name" {
  description = "Bus where the mission link publishes flight records."
  value       = module.this.event_bus_name
}

output "work_queue_arn" {
  description = "Work queue of the function."
  value       = module.this.work_queue_arn
}

output "dead_letter_queue_arn" {
  description = "Dead letter queue of the function."
  value       = module.this.dead_letter_queue_arn
}
