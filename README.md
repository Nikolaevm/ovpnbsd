# ovpnbsd
automatic configuration script openvpn on freebsd 9.x / 10.x with

# capabilities

- IP auto-detection
- The ability to set the number of customers generated

# Use

    USE: ovpnbsd.sh  <options>
    OPTIONS:
    -h            HELP.
    -c number     HOW MANY KEYS WILL BE GENERATED.
    -i ip         USE only selected ip.
    -a            1 IP ADDRESS = 1 CLIENT.(IN DEVELOPMENT SORRY.AVILABLE IN NEXT UPDATE)
    example:  sh ovpnbsd.sh  -c 12                  # generate 12 clients, use base ip
    example:  sh ovpnbsd.sh  -c 5 -i 1.2.3.4 # generate 12 clients ,use 1.2.3.4 as main
    
# to do

- Auto configure N clients = N ipadresses


### 2015 maxN 
