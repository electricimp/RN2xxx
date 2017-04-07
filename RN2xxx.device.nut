// MIT License
//
// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

// Driver Class for RN2903 and RN2483
class RN2xxx {

    static VERSION = "1.0.0";

    // UART Settings
    static BAUD_RATE = 57600;
    static WORD_SIZE = 8;
    static STOP_BITS = 1;

    // Class constants
    static LINE_FEED = 0x0A;
    static FIRST_ASCII_PRINTABLE_CHAR = 32;
    static RN2903_BANNER = "RN2903";
    static RN2483_BANNER = "RN2483";
    static RESET_TIMEOUT = 5;

    // Error messages
    static ERROR_BANNER_MISMATCH = "LoRa banner mismatch";
    static ERROR_BANNER_TIMEOUT = "LoRa banner timeout";

    // Pins
    _uart = null;
    _reset = null; // active low

    // Variables
    _timeout = null;
    _inReset = false;
    _resetCB = null;
    _banner = null;

    _buffer = null;
    _receiveHandler = null;

    _sending = false;
    _sendQueue = null;

    // Debug logging flag
    _debug = null;

    constructor(uart, reset, debug = false) {
        _debug = debug;
        _reset = reset;
        _uart = uart;
        _clearBuffer();
        _sendQueue = [];

        _reset.configure(DIGITAL_OUT, 1);
    }

    function init(banner, cb = null) {
        // Set reset flag
        _inReset = true;
        // Set callback
        _resetCB = cb;
        // Set banner
        _banner = banner;

        // Hold reset pin low (active)
        _reset.write(0);
        // Start timeout timer
        _timeout = imp.wakeup(RESET_TIMEOUT, _initTimeoutHandler.bindenv(this));
        // Configure UART, _uartReceive handler will receive a banner to check
        _uart.configure(BAUD_RATE, WORD_SIZE, PARITY_NONE, STOP_BITS, NO_CTSRTS, _uartReceive.bindenv(this));
        // Release reset pin
        _reset.write(1);
    }

    function hwReset(cb = null) {
        // Toggle reset flag
        _inReset = true;
        _resetCB = cb;
        _reset.write(0);
        // Start timeout timer
        _timeout = imp.wakeup(RESET_TIMEOUT, _initTimeoutHandler.bindenv(this));
        imp.sleep(0.01);
        _reset.write(1);
    }

    function send(cmd) {
        if (_sending || _inReset) {
            _sendQueue.push(cmd);
        } else {
            _sending = true;
            _log("sent: "+ cmd);
            _uart.write(cmd+"\r\n");
        }
    }

    function setReceiveHandler(cb) {
        _receiveHandler = cb;
    }

    function _uartReceive() {
        // Only printable charaters are expected in a response
        // All responses end in a line feed
        local b = _uart.read();
        while(b >= 0) {
            // Add expected charaters to buffer
            if (b >= FIRST_ASCII_PRINTABLE_CHAR) {
                _buffer += b.tochar();
            // We received a complete response, process it
            } else if (b == LINE_FEED) {
                // Debug log received data
                _log("received: " + _buffer);

                // Pass recieved data to handler & clear buffer
                _processBuffer(_buffer);

                // Send next command
                local queueLen = _sendQueue.len();
                if (queueLen > 0) {
                    _sending = false;
                    send(_sendQueue.remove(0));
                } else if (queueLen == 0 && _sending) {
                    _sending = false;
                }
            }
            b = _uart.read();
        }
    }

    function _processBuffer(buffer) {
        if (_inReset) {
           // Check banner if we have one
            local err = (_banner) ? _checkBanner(buffer) : null;
            // Cancel reset timer
            if (_timeout) _cancelTimer(_timeout);
            // Trigger reset Callback, or log error
            if (_resetCB) {
                imp.wakeup(0, function() {
                    _resetCB(err);
                    _resetCB = null;
                }.bindenv(this));
            } else if (err) {
                server.error(err);
            }
            // Toggle reset flag
            _inReset = false;
        } else if (_receiveHandler) {
            _receiveHandler(buffer);
        }
        _clearBuffer();
    }

    function _clearBuffer() {
        _buffer = "";
    }

    function _cancelTimer(timer) {
        imp.cancelwakeup(timer);
        timer = null;
    }

    function _checkBanner(data) {
        // Check for the expected banner
        if (data.slice(0, _banner.len()) != _banner) {
            _log(_banner);
            return ERROR_BANNER_MISMATCH;
        }
        return null;
    }

    function _initTimeoutHandler() {
        (_resetCB) ? _resetCB(ERROR_BANNER_TIMEOUT) : server.error(ERROR_BANNER_TIMEOUT);
        // Clear reset flag
        _inReset = false;
        _timeout = null;
    }

    function _log(msg) {
        if (_debug) server.log(msg);
    }

}
