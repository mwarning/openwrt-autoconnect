#!/bin/sh

# Interface device section in /etc/config/wireless, e.g. radio0
selected_cfg="$1"

#######################################################

. /lib/functions.sh

# Result
scanned_ssid=""
scanned_channel=""

if [ "$(uci -q get wireless.${selected_cfg})" != "wifi-device" ]; then
  echo "Interface section not found: $selected_cfg"
  exit 1
fi

# returns e.g. wlan0
selected_dev=$(jsonfilter -s "$(wifi status)" -e "@.${selected_cfg}.interfaces[0].ifname")


config_load 'wireless'

is_cfg_disabled() {
  local device="$1"
  local disabled=1
  uci_get disabled "$device" disabled
  [ $disabled -eq 0 ]
}

if is_cfg_disabled "$selected_cfg"; then
  echo "WIFI configuration disabled: $selected_cfg"
  exit 1
fi

if [ ! -f /sys/class/net/${selected_dev}/operstate ]; then
  echo "Device does not exist: $selected_dev"
  exit 1
fi

listed_ssid() {
  local search_ssid="$1"
  local found=0

  check() {
    local cfg="$1"
    local ssid mode network

    config_get ssid $cfg ssid
    config_get mode $cfg mode
    config_get network $cfg network

    # wifi-iface section in station mode and matching SSID
    if [ "$mode" = "sta" -a "$network" = "wan" -a "$search_ssid" = "$ssid" ]; then
      found=1
      return 0
    else
      return 1
    fi
  }

  config_foreach check 'wifi-iface'
  return $found
}

select_wifi() {
  local scanned_ssid="$1"
  local scanned_channel="$2"
  local changed=0

  apply() {
    local cfg="$1"
    local device ssid disabled channel

    config_get device $cfg device
    config_get ssid $cfg ssid
    config_get disabled $cfg disabled
    config_get fooo #
    config_get channel $selected_cfg channel

    if [ "$device" = "$selected_cfg" ]; then
      if [ "$ssid" = "$scanned_ssid" ]; then
        if [ $disabled -ne 0 -o $channel -ne $scanned_channel ]; then
          uci set wireless.$cfg.disabled=0
          uci set wireless.$selected_cfg.channel=$scanned_channel
          changed=1
        fi
      else
        if [ $disabled -ne 1 ]; then
          uci set wireless.$cfg.disabled=1
          changed=1
        fi
      fi
    fi
  }

  config_foreach apply 'wifi-iface'

  echo "SSID: '$scanned_ssid', channel: $scanned_channel"
  if [ $changed -eq 1 ]; then
    echo "Configuration changed - reload"
    wifi
  else
    echo "Configuration unchanged"
  fi
}

parse_scan() {
  local iw_scan="$1"
  local ssid=""
  local channel=""

  echo "$iw_scan" | while read line
  do
    case "$line" in
      "BSS"*)
        ssid=""
        channel=""
        ;;
      "SSID: "*)
        ssid="${line:6}"
        ;;
      "* primary channel: "*)
        channel="${line:19}"
        ;;
    esac

    if [ -n "$channel" -a -n "$ssid" ]; then
      if listed_ssid "$ssid"; then
        select_wifi "$ssid" "$channel"
        return
      fi

      ssid=""
      channel=""
    fi
  done
}

iw_scan="$(iw dev ${selected_dev} scan 2> /dev/null)"
if [ $? -eq 0 ]; then
  parse_scan "$iw_scan"
else
  echo "WIFI scan failed - abort"
  exit 1
fi

exit 0