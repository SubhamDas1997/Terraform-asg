# Configuring the provider
provider "aws" {
  profile = "${var.profile}"
  region = "${var.region}"
}

# Creating template file from the nginx install script as user data
data "template_file" "user_data" {
  template = "${file("script.sh")}"
}

# Configuring custom VPC
resource "aws_vpc" "project3-vpc" {
  cidr_block = "${var.vpc-cidr}"

  tags = {
    Name = "project3-vpc"
  }
}

# Configuring 2 public subnets
resource "aws_subnet" "project3-public-subnet-1" {
  vpc_id = "${aws_vpc.project3-vpc.id}"
  cidr_block = "${var.subnet-1-cidr}"
  availability_zone = "${var.az-1}"
  map_public_ip_on_launch = true

  tags = {
    Name = "project3-public-subnet-1"
  }
}

resource "aws_subnet" "project3-public-subnet-2" {
  vpc_id = "${aws_vpc.project3-vpc.id}"
  cidr_block = "${var.subnet-2-cidr}"
  availability_zone = "${var.az-2}"
  map_public_ip_on_launch = true

  tags = {
    Name = "project3-public-subnet-2"
  }
}

# Configuring Internet Gateway and Route Tables with associations
resource "aws_internet_gateway" "project3-igw" {
  vpc_id = "${aws_vpc.project3-vpc.id}"

  tags = {
    Name = "project3-igw"
  }
}

resource "aws_route_table" "project3-rtb" {
  vpc_id = "${aws_vpc.project3-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.project3-igw.id}"
  }

  tags = {
    Name = "project3-rtb"
  }
}

resource "aws_route_table_association" "project3-rtb-assosiation-1" {
  route_table_id = "${aws_route_table.project3-rtb.id}"
  subnet_id = "${aws_subnet.project3-public-subnet-1.id}"
}

resource "aws_route_table_association" "project3-rtb-assosiation-2" {
  route_table_id = "${aws_route_table.project3-rtb.id}"
  subnet_id = "${aws_subnet.project3-public-subnet-2.id}"
}

# Configuring Security groups for webserver and load balancer
resource "aws_security_group" "webserver-sg" {
  name = "web-sg"
  description = "Opens port 80, 22 & 443 for Nginx webserver"
  vpc_id = "${aws_vpc.project3-vpc.id}"

  egress {
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
  }

  ingress {
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
  }

  ingress {
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
  }

  ingress {
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
  }

  tags = {
    Name = "project3-webserver-sg"
  }
}

resource "aws_security_group" "lb-sg" {
  name = "lb-sg"
  description = "Opens port 80 for Nginx lb"
  vpc_id = "${aws_vpc.project3-vpc.id}"

  egress {
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
  }

  ingress {
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
  }

  tags = {
    Name = "project3-lb-sg"
  }
}

# Configuring KeyPair for SSH
resource "aws_key_pair" "project3-webserver-keypair" {
  key_name = "Project3KeyPair"
  public_key = "${file("${var.public-key}")}"
}

# Configuring the launch configurations with instance details
resource "aws_launch_configuration" "project3-launch-config" {
  name = "project3-launch-config"
  image_id = "${var.image-id}"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.project3-webserver-keypair.key_name}"
  security_groups = ["${aws_security_group.webserver-sg.id}"]
  user_data = "${data.template_file.user_data.rendered}"
}

# Configuring Classic Load Balancer
resource "aws_elb" "project3-elb" {
  name = "project3-elb"
  security_groups = [
    "${aws_security_group.lb-sg.id}"
  ]

  subnets = [
    "${aws_subnet.project3-public-subnet-1.id}",
    "${aws_subnet.project3-public-subnet-2.id}"
  ]

  cross_zone_load_balancing = true
  
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
}

# Configuring Auto Scaling Group
resource "aws_autoscaling_group" "project3-asg" {
  name = "${aws_launch_configuration.project3-launch-config.name}-asg"
  launch_configuration = "${aws_launch_configuration.project3-launch-config.name}"
  vpc_zone_identifier  = [
    "${aws_subnet.project3-public-subnet-1.id}",
    "${aws_subnet.project3-public-subnet-2.id}"
  ]

  min_size = "${var.min-size}"
  desired_capacity = "${var.desired-size}"
  max_size = "${var.max-size}"
  
  health_check_type = "ELB"
  load_balancers = ["${aws_elb.project3-elb.id}"]
  
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity = "1Minute"
  
  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }
  
  tag {
    key                 = "Name"
    value               = "project3-asg"
    propagate_at_launch = true
  }
}

# Configuring scale UP policy
resource "aws_autoscaling_policy" "project3-asg-policy-up" {
  name = "project3-asg-policy-up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.project3-asg.name}"
}

# Configuring scale UP policy ALARM
resource "aws_cloudwatch_metric_alarm" "project3-asg-cpu-alarm-up" {
  alarm_name = "project3-asg-cpu-alarm-up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "75"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.project3-asg.name}"
  }
  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ "${aws_autoscaling_policy.project3-asg-policy-up.arn}" ]
}

# Configuring scale DOWN policy
resource "aws_autoscaling_policy" "project3-asg-policy-down" {
  name = "project3-asg-policy-down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.project3-asg.name}"
}

# Configuring scale DOWN policy ALARM
resource "aws_cloudwatch_metric_alarm" "project3-asg-cpu-alarm-down" {
  alarm_name = "project3-asg-cpu-alarm-down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "25"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.project3-asg.name}"
  }
  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ "${aws_autoscaling_policy.project3-asg-policy-down.arn}" ]
}

# Displaying ELB DNS name as output
output "dns_name" {
  description = "The DNS name of the load balancer."
  value       = "${aws_elb.project3-elb.dns_name}"
}