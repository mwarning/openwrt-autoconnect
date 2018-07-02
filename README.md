# SSID Autoconnect

A script that connects to any of a list of preconfigured SSIDs.

(Warning: not working yet)

Example configuration in /etc/config/wireless:

```
config wifi-device 'radio0'
  option type 'mac80211'
  #option channel '11' # must no be set!
  option hwmode '11g'
  option path 'platform/ar933x_wmac'
  option htmode 'HT20'

# first network
config wifi-iface 'home_radio0'
  option device 'radio0'
  option network 'wan'
  option mode 'sta'
  option ssid 'home_wifi_network'
  option key '12345678'
  option encryption 'psk2'
  option channel '11' # required

# second network
config wifi-iface 'lab_radio0'
  option device 'radio0'
  option network 'wan'
  option mode 'sta'
  option ssid 'work_wifi_network'
  option key '87654321'
  option encryption 'psk2'
  option channel '5' # required
```
