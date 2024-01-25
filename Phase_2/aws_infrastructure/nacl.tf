resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "PublicNACL"
  }
}

resource "aws_network_acl_association" "public_nacl_association" {
  network_acl_id = aws_network_acl.public_nacl.id
  subnet_id      = aws_subnet.subnet1.id
}
