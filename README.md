# aws-vpc-module
## Overview
This project sets up an AWS Virtual Private Cloud (VPC) using Terraform. The architecture is designed for high availability and secure networking. It includes:
* VPC
* Internet Gateway associated with VPC
* 2 Public Subnets
* 2 Private Subnets
* 2 Database Subnets
* Database subnet group
* EIP
* NAT Gateway
* Public Route table
* Private Route table
* Database Route table
* Routes
* Route table associations with subnets
* Peering with default VPC(if Required)
* Peering routes in acceptor and requestor route tables
---
# AWS VPC Architecture with Multi-AZ, Subnets, Routing, and Peering
![alt text](images/vpc.jpg)

---
## VPC and Subnet Structure
- VPC Name: `expense-dev-vpc`
- Total Subnets: 6
  - 2 Public Subnets (for Frontend)
  - 2 Private Subnets (for Backend)
  - 2 Private Subnets (for Database)
- Availability Zones: Spread across 2 Availability Zones (e.g., `us-east-1a` and `us-east-1b`)
---

## Internet Connectivity
- Public Subnets:
  - Frontend services are deployed here.
  - Connected to the Internet via an Internet Gateway.

- Private Subnets (Backend and Database):
  - Cannot access the Internet directly.
  - Outbound internet access is provided through a NAT Gateway located in one of the public subnets.
  - The NAT Gateway uses an Elastic IP.
  - Route Tables are configured to send private subnet traffic to the NAT Gateway.
---

## VPC Peering
- A VPC Peering connection is created between the custom VPC (`expense-dev-vpc`) and the default VPC.
- Route tables are updated for bidirectional communication between the subnets of both VPCs.
- This allows secure, internal communication between all subnets.
---

## Route Tables and Routes
- Public Route Table:
  - Routes internet-bound traffic (`0.0.0.0/0`) to the Internet Gateway.
  - Contains local routes for VPC-internal communication.
  - Routes to the default VPC subnets through the peering connection.

- Private Route Tables (Backend and Database):
  - Routes internet-bound traffic (`0.0.0.0/0`) to the NAT Gateway.
  - Local route for internal VPC communication.
  - Routes to the default VPC subnets through the peering connection.

- Database Subnets:
  - No internet access.
  - Only local and peering routes for internal, restricted access.
---

## Security and Design Highlights
- Frontend services are hosted in public subnets and accessible from the internet.
- Backend and database services are isolated in private subnets with no direct internet access.
- NAT Gateway allows private subnets to reach the internet securely without exposing them.
- Peering connection enables safe, bidirectional communication with the default VPC.
- All subnets are distributed across two Availability Zones for high availability and redundancy.
---

## Summary
This setup provides a secure and scalable AWS network architecture. It separates public-facing services from internal logic and data layers, ensures controlled traffic flow with route tables and NAT, and allows secure cross-VPC communication using peering.

---
# Inputs
* project_name (Mandatory): User must supply their project name.
* environment (Mandatory): User must supply their environment name.
* vpc_cidr (Mandatory): User must supply their VPC CIDR.
* enable_dns_hostnames (Optional): defaults to true.
* common_tags (Optional): Default is empty. User can supply tags in map(string) format.
* vpc_tags (Optional): Default is empty. User can supply tags in map(string) format.
* igw_tags (Optional): Default is empty. User can supply tags in map(string) format.
* public_subnet_cidrs (Mandatory): User must supply only 2 valid public subnet CIDR.
* public_subnet_tags (Optional): Default is empty. User can supply tags in map(string) format.
* private_subnet_cidrs (Mandatory): User must supply only 2 valid private subnet CIDR.
* private_subnet_tags (Optional): Default is empty. User can supply tags in map(string) format.
* database_subnet_cidrs (Mandatory): User must supply only 2 valid database subnet CIDR.
* database_subnet_tags (Optional): Default is empty. User can supply tags in map(string) format.
* db_subnet_group_tags (Optional): Default is empty. User can supply tags in map(string) format.
* nat_gateway_tags (Optional): Default is empty. User can supply tags in map(string) format.
* public_route_table_tags (Optional): Default is empty. User can supply tags in map(string) format.
* private_route_table_tags (Optional): Default is empty. User can supply tags in map(string) format.
* database_route_table_tags (Optional): Default is empty. User can supply tags in map(string) format.
* is_peering_required (Optional): defaults to false
* vpc_peering_tags (Optional): Default is empty. User can supply tags in map(string) format.

# Output Purpose
* vpc_id – Used to attach additional resources (EC2, ALB, SGs) to this VPC.
* public_subnet_ids – Used to place internet-facing resources like ALBs or EC2 instances.
* private_subnet_ids – Used to deploy backend services that should not be exposed publicly.
* database_subnet_ids – Used for creating RDS instances in isolated subnets.
* database_subnet_group_name – Required when launching an RDS instance within these DB subnets.

---
## Understanding `merge()`, `slice()` Functions & Data Sources
---

### 1. `merge()` Function (Used for Tags)
The `merge()` function combines multiple maps into a single map.
**Example in the module:**
```hcl
tags = merge(var.common_tags, var.vpc_tags, { Name = local.resource_name })
```
Purpose:
Adds default/common tags
Supports resource-specific tags
Appends the final Name tag
Later maps override earlier ones

Example:
common_tags = { Project = "Expense" }
vpc_tags    = { Owner = "DevOps" }
merge(common_tags, vpc_tags)
Result:
{ Project = "Expense", Owner = "DevOps" }


### 2. `slice()` Function (Selecting Availability Zones)

module uses:
```hcl
az_names = slice(data.aws_availability_zones.available.names, 0, 2)
```
Purpose:
Fetches all AZs in the region but selects only two of them.

Example:
Region AZ list:
["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]

Applying slice:
["us-east-1a", "us-east-1b"]

VPC design uses exactly two AZs to create:
2 Public Subnets
2 Private Subnets
2 Database Subnets
Ensures high availability and consistent subnet spread.

---

### 3. Data Source for Availability Zones
```hcl
data "aws_availability_zones" "available" {
  state = "available"
}
```
Purpose:
Fetches AZs dynamically based on the region
Removes dependency on hardcoding AZ names

Example (us-east-1):
Available AZs:
us-east-1a
us-east-1b
us-east-1c
us-east-1d

module uses only:
us-east-1a
us-east-1b

These AZs are used to create:
Public Subnets
Private Subnets
Database Subnets

---
### 4. Data Sources Used in VPC Peering
Fetching the Default VPC
```hcl
data "aws_vpc" "default" {
  default = true
}
```
Purpose:
Automatically fetches the default VPC ID
No manual VPC ID input required
Fetching the Default VPC Main Route Table
```hcl
data "aws_route_tables" "main" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}
```
Purpose:
Identifies the main route table of the default VPC
Needed for adding return routes during VPC peering.

Why These Data Sources Are Important for Peering?
When peering is enabled:
our VPC (Requestor)
Adds routes in public, private, and database route tables
Sends traffic to the default VPC through the peering connection

Default VPC (Acceptor)
Adds a return route to your VPC CIDR in its main route table

Result:
* Fully functional two-way communication between both VPCs
* No need for manual route creation
---