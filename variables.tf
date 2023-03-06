# Defining profile
variable "profile" {
  default = "nuveproGL"
}

# Defining region
variable "region" {
  default = "us-east-1"
}

# Defining CIDR blocks
variable "vpc-cidr" {
  default = "10.0.0.0/16"
}

variable "subnet-1-cidr" {
  default = "10.0.1.0/24"
}

variable "subnet-2-cidr" {
  default = "10.0.2.0/24"
}

# Defining Availability Zones
variable "az-1" {
  default = "us-east-1a"
}

variable "az-2" {
  default = "us-east-1c"
}

# Defining public key
variable "public-key" {
  default = "Project3KeyPair.pub"
}

# Defining Image ID
variable "image-id" {
  default = "ami-006dcf34c09e50022"
}

# Defining ASG instance count details
variable "min-size" {
  default = "1"
}

variable "desired-size" {
  default = "2"
}

variable "max-size" {
  default = "4"
}