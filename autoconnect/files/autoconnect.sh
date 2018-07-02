#!/bin/sh

# Part of the autoconnect package

. /lib/functions.sh

# config_set is buggy, use wrapper
_config_set() {
  uci set wireless.$1.$2=$3
  config_set "$1" "$2" "$3"
}

config_load 'wireless'

is_connected() {
  local device_cfg="$1"
  local iface_cfg="$2"
  local ifname=$(ubus call network.wireless status | jsonfilter -e "$.\"$device_cfg\".interfaces[@.section=\"$iface_cfg\"].ifname")
  ip addr list dev "$ifname" 2> /dev/null | grep -v "inet6 fe80" | grep -q "inet"
}

# reload and test current wifi setup
wifi_connect() {
  local device_cfg="$1"
  local iface_cfg="$2"

  ubus call network reload

  for i in 2 4 8; do
    sleep $i
    if is_connected "$device_cfg" "$iface_cfg"; then
      return 0
    fi
  done

  return 1
}

# Enable a single wifi-iface section
setup_ifaces() {
  local select_cfg="$1"

  setup_iface() {
    local cfg="$1"
    local device ssid mode channel

    config_get device $cfg device
    config_get ssid $cfg ssid
    config_get mode $cfg mode
    config_get channel $cfg channel

    if [ "$cfg" = "$select_cfg" ]; then
      _config_set "$cfg" disabled 0
      # Set device config to required channel
      _config_set "$device" channel "$channel"
      config="$cfg"
    else
      _config_set "$cfg" disabled 1
    fi
  }

  config_foreach setup_iface 'wifi-iface'
}

# all wifi-device sections
list_device_cfgs() {
  print_cfg() {
    local cfg="$1"
    local channel

    config_get channel $cfg channel

    if [ -z "$channel" ]; then
      echo "$cfg"
    fi
  }

  config_foreach print_cfg 'wifi-device'
}

# all wifi-ifaces sections of a wifi-device
list_iface_cfgs() {
  local device_cfg="$1"

  print_cfg() {
    local cfg="$1"
    local device mode channel

    config_get device $cfg device
    config_get mode $cfg mode
    config_get channel $cfg channel

    if [ "$device" = "$device_cfg" -a "$mode" = "sta" -a -n "$channel" ]; then
      echo "$cfg"
    fi
  }

  config_foreach print_cfg 'wifi-iface'
}

for device_cfg in $(list_device_cfgs); do
  iface_cfgs=$(list_iface_cfgs "$device_cfg")

  for iface_cfg in $iface_cfgs; do
    # check for existing connection
    if is_connected "$device_cfg" "$iface_cfg"; then
      echo "already is_connected"
      iface_cfgs=""
      break
    fi
  done

  for iface_cfg in $iface_cfgs; do
    setup_ifaces "$iface_cfg"
    if wifi_connect "$device_cfg" "$iface_cfg"; then
      echo "connection established"
      break
    fi
  done
done

exit 0