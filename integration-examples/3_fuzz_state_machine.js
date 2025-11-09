// Example: Fuzzing a State Machine
// This shows how to fuzz stateful code

// ===== STATE MACHINE (the code you want to fuzz) =====

class ConnectionStateMachine {
    constructor() {
        this.state = 'DISCONNECTED';
        this.buffer = [];
        this.authenticated = false;
    }

    connect() {
        if (this.state !== 'DISCONNECTED') {
            throw new Error('Already connected');
        }
        this.state = 'CONNECTED';
        this.buffer = [];
        this.authenticated = false;
    }

    authenticate(password) {
        if (this.state !== 'CONNECTED') {
            throw new Error('Not connected');
        }
        if (password === 'secret123') {
            this.authenticated = true;
            this.state = 'AUTHENTICATED';
        } else {
            throw new Error('Authentication failed');
        }
    }

    sendData(data) {
        if (this.state !== 'AUTHENTICATED') {
            throw new Error('Not authenticated');
        }
        if (data.length > 1000) {
            throw new Error('Data too large');
        }
        this.buffer.push(data);
    }

    getData() {
        if (this.state !== 'AUTHENTICATED') {
            throw new Error('Not authenticated');
        }
        return this.buffer.shift();
    }

    disconnect() {
        if (this.state === 'DISCONNECTED') {
            throw new Error('Already disconnected');
        }
        this.state = 'DISCONNECTED';
        this.buffer = [];
        this.authenticated = false;
    }

    getState() {
        return {
            state: this.state,
            authenticated: this.authenticated,
            bufferSize: this.buffer.length
        };
    }
}

// ===== FUZZER CODE =====

// Commands that the fuzzer can execute
const COMMANDS = {
    CONNECT: 0,
    AUTHENTICATE: 1,
    SEND_DATA: 2,
    GET_DATA: 3,
    DISCONNECT: 4,
    GET_STATE: 5
};

try {
    const machine = new ConnectionStateMachine();

    // Execute a sequence of commands based on fuzzer input
    let offset = 0;

    while (offset < FuzzerInput.length) {
        const cmd = FuzzerInput[offset] % 6;
        offset++;

        switch (cmd) {
            case COMMANDS.CONNECT:
                machine.connect();
                break;

            case COMMANDS.AUTHENTICATE:
                // Extract password from next bytes
                const passLen = Math.min(10, FuzzerInput.length - offset);
                const password = String.fromCharCode.apply(
                    null,
                    FuzzerInput.slice(offset, offset + passLen)
                );
                offset += passLen;
                machine.authenticate(password);
                break;

            case COMMANDS.SEND_DATA:
                // Extract data length and data
                if (offset < FuzzerInput.length) {
                    const dataLen = FuzzerInput[offset++];
                    const data = String.fromCharCode.apply(
                        null,
                        FuzzerInput.slice(offset, offset + dataLen)
                    );
                    offset += dataLen;
                    machine.sendData(data);
                }
                break;

            case COMMANDS.GET_DATA:
                machine.getData();
                break;

            case COMMANDS.DISCONNECT:
                machine.disconnect();
                break;

            case COMMANDS.GET_STATE:
                machine.getState();
                break;
        }

        // Limit iterations to prevent infinite loops
        if (offset > 1000) break;
    }

} catch (e) {
    // Expected errors for invalid state transitions
    // The fuzzer will find sequences that cause unexpected crashes
}

// Run this fuzzer with:
// ./jsfuzzer --js=integration-examples/3_fuzz_state_machine.js corpus -max_total_time=60
//
// This will test various sequences of state transitions and find edge cases
