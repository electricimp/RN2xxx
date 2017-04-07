// Copyright (c) 2017 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Hardware Test Setup
// Wiresless Gateway Accelerator rev2.0
// LoRa RF 2click module with RN2903
 class RN2xxx_TestCase extends ImpTestCase {

    lora = null;
    defaultFreq = "923300000";
    banner = RN2xxx.RN2903_BANNER;
    /**
     * Initialize sensor
     */
    function setUp() {
        local UART = hardware.uart1;
        local RESET_PIN = hardware.pinH;
        lora = RN2xxx(UART, RESET_PIN, true);
        return Promise(function(resolve, reject) {
            lora.init(banner, function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve("LoRa initialized");
                }
            }.bindenv(this))
        }.bindenv(this))
    }

    /**
     * Test hwReset
     */
    function testHardwareReset() {
        return Promise(function (resolve, reject) {
            local counter = 0;
            local newFreq = "915000000";
            local errUnexpectedRes = "Received unexpected response from module";
            lora.setReceiveHandler(function(res) {
                counter++;
                switch (counter) {
                    case 1:
                        try {
                            this.assertEqual(res, "ok");
                        } catch(e) {
                            reject(e)
                        }
                        break;
                    case 2:
                        try {
                            this.assertEqual(newFreq, res);
                        } catch(e) {
                            reject(e);
                        }
                        break;
                    case 3:
                        try {
                            this.assertEqual(defaultFreq, res);
                            resolve("Reset restored default settings")
                        } catch(e) {
                            reject(e);
                        }
                        break;
                }
            }.bindenv(this));
            // Change Freq
            lora.send("radio set freq " + newFreq);
            // Confirm Change
            lora.send("radio get freq");
            // Make sure Freq change has time to complete
            imp.wakeup(5, function() {
                // Reset
                lora.hwReset();
                // Confirm Freq changed back to defualt
                lora.send("radio get freq");
            }.bindenv(this));
        }.bindenv(this))
    }

    /**
     * Test multiple sends
     */
    function testMultiSend() {
        return Promise(function (resolve, reject) {
            local counter = 0;
            local newFreq = "905550000";
            local errUnexpectedRes = "Received unexpected response from module";
            lora.setReceiveHandler(function(res) {
                counter++;
                switch (counter) {
                    case 1:
                        try {
                            res = res.tointeger();
                            this.assertBetween(res, 902000000, 928000000);
                        } catch(e) {
                            reject(e)
                        }
                        break;
                    case 2:
                        try {
                            this.assertEqual(res, "ok");
                        } catch(e) {
                            reject(e)
                        }
                        break;
                    case 3:
                        try {
                            this.assertEqual(newFreq, res);
                            resolve("Received expected responses from module.")
                        } catch(e) {
                            reject(e);
                        }
                        break;
                }
            }.bindenv(this));
            lora.send("radio get freq");
            lora.send("radio set freq " + newFreq);
            lora.send("radio get freq");
        }.bindenv(this));
    }

    /**
     * Test send/receive
     */
    function testSendRecieve() {
        return Promise(function (resolve, reject) {
            local newFreq = "921000000";
            lora.setReceiveHandler(function(res) {
                try {
                    this.assertEqual("ok", res);
                    resolve("Received expected response from module.")
                } catch(e) {
                    reject(e);
                }
            }.bindenv(this));
            lora.send("radio set freq " + newFreq);
        }.bindenv(this));
    }

    function tearDown() {
        lora.hwReset();
    }

 }
