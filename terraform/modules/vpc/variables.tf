variable "vpc_cidr"     { 
	description = "VPC CIDR"        
	type = string 
	default = "10.0.0.0/16" 
}

variable "azs"          { 
	description = "Availability zones" 
	type = list(string) 
	default = ["us-east-1a","us-east-1b","us-east-1c"] 
}

variable "project_name" { 
	description = "Project tag name" 
	type = string 
	default = "capstone" 
}
