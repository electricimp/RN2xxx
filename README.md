# RN2xxx

This library provides driver code for Microchip’s [RN2903](http://ww1.microchip.com/downloads/en/DeviceDoc/50002390B.pdf) and [RN2483](http://ww1.microchip.com/downloads/en/DeviceDoc/50002346A.pdf) Low-Power Long Range LoRa Technology Transceiver modules.  These modules provide low-power solution for long range wireless data transmission that complies with the LoRaWAN Class A protocol specifications.

**To use this library, add `#require "RN2xxx.device.nut:1.0.0"` to the top of your device code.**

## Class Usage

### Constructor: RN2xxx(*uart, reset[, debug]*)

The constructor takes two required parameters to instantiate the class: *uart* the uart bus that the chip is connected to, and *reset* the pin the module's reset pin is connected to. The reset pin must be active low. The constructor will configure the reset pin. The optional *debug* parameter is a boolean that enables debug logging on incoming and outgoing uart traffic.

```squirrel
local UART = hardware.uart1;
local RESET_PIN = hardware.pinH;

lora <- RN2xxx(UART, RESET_PIN);
```

## Class Methods

### init(*banner[, callback]*)

The *init()* method configures the uart and checks for the module's expected banner. The method takes one required parameter *banner*, RN2xxx.RN2903_BANNER for the RN2903 module or RN2xxx.RN2483 for the RN2483 module, and one optional parameter *callback*, a function that will run when the initialization has completed. The *callback* function takes one parameter, it will contain an error message if initialization fails or null if initialization was successful.

```
lora.init(RN2xxx.RN2903_BANNER function(err) {
  if (err) {
    server.error(err);
  } else {
    lora.send("radio set mod lora");
  }
});
```

### hwReset()

The *hwReset()* method toggles the reset pin. This method blocks for 0.01 seconds.

```
lora.hwReset()
```

### send(*command*)

The *send()* method takes one required parameter *command*, a string command. Here are the command references for each module: [RN2903](http://ww1.microchip.com/downloads/en/DeviceDoc/40001811A.pdf), [RN2483](http://ww1.microchip.com/downloads/en/DeviceDoc/40001784B.pdf). Below are some examples of a few different commands.

```
// set the radio mode to lora
lora.send("radio set mod lora");

// set the radio to continuous receive mode
lora.send("radio rx 0");

// send "TX OK" message
lora.send("radio tx FF0000005458204F4B00");
```

### setReceiveHandler(*receiveCallback*)

The *setReceiveHandler()* takes one required parameter *receiveCallback*, a function that will be called whenever a response or data is received. The *receiveCallback* takes one parameter the response/data received.

```
function receive(data) {
    if (data.len() > 10 && data.slice(0,10) == "radio_rx  ") {
        // We have received a packet
        // Add code to handle data here, for now just log the incoming data
        server.log(data);
        // Send ACK
        lora.send("radio tx FF0000005458204F4B00");
    } else if (data == "radio_tx_ok" || data == "radio_err") {
        // Queue next receive
        lora.send("radio rx 0");
    } else if (data != "ok") {
        // Unexpected response
        server.error(data);
    }
}

lora.setReceiveHandler(receive.bindenv(this));
```

## Full Example:

```squirrel
#require "RN2xxx.device.nut:1.0.0"

// LoRa Settings
const RADIO_MODE = "lora";
const RADIO_FREQ = 915000000;
const RADIO_SPREADING_FACTOR = "sf7"; // 128 chips
const RADIO_BANDWIDTH = 125;
const RADIO_CODING_RATE = "4/5";
const RADIO_CRC = "on"; // crc header enabled
const RADIO_SYNC_WORD = 12;
const RADIO_WATCHDOG_TIMEOUT = 0;
const RADIO_POWER_OUT = 14;
const RADIO_RX_WINDOW_SIZE = 0; // contiuous mode

// LoRa Commands
const MAC_PAUSE = "mac pause";
const RADIO_SET = "radio set";
const RADIO_RX = "radio rx";
const RADIO_TX = "radio tx";

// LoRa Com variables
const TX_HEADER = "FF000000";
const TX_FOOTER = "00";
const ACK_COMMAND = "5458204F4B" // "TX OK"

local initCmdIdx = 0;
initCommands <- [ format("%s mod %s", RADIO_SET, RADIO_MODE),
                  format("%s freq %i", RADIO_SET, RADIO_FREQ),
                  format("%s sf %s", RADIO_SET, RADIO_SPREADING_FACTOR),
                  format("%s bw %i", RADIO_SET, RADIO_BANDWIDTH),
                  format("%s cr %s", RADIO_SET, RADIO_CODING_RATE),
                  format("%s crc %s", RADIO_SET, RADIO_CRC),
                  format("%s sync %i", RADIO_SET, RADIO_SYNC_WORD),
                  format("%s wdt %i", RADIO_SET, RADIO_WATCHDOG_TIMEOUT),
                  format("%s pwr %i", RADIO_SET, RADIO_POWER_OUT),
                  MAC_PAUSE,
                  format("%s %i", RADIO_RX, RADIO_RX_WINDOW_SIZE) ];

local UART = hardware.uart1;
local RESET_PIN = hardware.pinH;
lora <- RN2xxx(UART, RESET_PIN);

function receive(data) {
    if (data.len() > 10 && data.slice(0,10) == "radio_rx  ") {
        // We have received a packet
        // Add code to handle data here, for now just log the incoming data
        server.log(data);
        // Send ACK
        lora.send( format("%s %s%s%s", RADIO_TX, TX_HEADER, ACK_COMMAND, TX_FOOTER) );
    } else if (data == "radio_tx_ok" || data == "radio_err") {
        // Queue next receive
        lora.send( format("%s %i", RADIO_RX, RADIO_RX_WINDOW_SIZE) );
    } else if (data != "ok") {
        // Unexpected response
        server.error(data);
    }
}

function sendNextInitCmd(data = null) {
    if (data == "invalid_param") {
        // Set init command failed - log it
        server.error("Radio command failed: " + data);
    } else if (initCmdIdx < initCommands.len()) {
        // Get command at the current index pointer, and increment the index pointer
        local command = initCommands[initCmdIdx++];
        server.log(command);
        // Send command to LoRa
        lora.send(command);
    } else {
        server.log("LoRa radio in receive mode...");
        // Radio ready to receive, set to our receive handler
        lora.setReceiveHandler(receive.bindenv(this));
    }
}

function loraInitHandler(err) {
    if (err) {
        server.error(err);
    } else {
        // Set receive callback to loop through initialization commands
        lora.setReceiveHandler(sendNextInitCmd.bindenv(this));
        // Start sending initialization commands
        sendNextInitCmd();
    }
}

// Initialize LoRa Radio and open a receive handler
lora.init(RN2xxx.RN2903_BANNER loraInitHandler);
```

## License

The RN2xxx library is licensed under the [MIT License](/LICENSE).
