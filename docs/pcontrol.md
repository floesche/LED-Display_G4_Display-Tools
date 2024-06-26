---
title:  Panels Controller
parent: Generation 4
nav_order: 15
---

# The `PanelsController` class 

Running the [G4 Host](software_setup.md) software initiates the IO card of the system to start a TCP/IP server on the `localhost` at port `62222`. Through this TCP/IP connection, it is possible to communicate directly with the arena. Here we list the commands available in `PanelsController` which would allow you to implement the same functionality in a language of your choosing. For simplicity we document both, MATLAB's `PanelsController` class as well as the underlying TCP/IP data exchange. For the TCP/IP we use python as an example.

The TCP/IP commands follow a common structure: the first byte represents the length of package following the length command and the second byte is a command ID (_Stream frame_ and _Change root directory_ are notably different, they start with the command IDs followed by two bytes representing the length of the packet). This means, a two-byte TCP/IP command consists of a length of `1` and the command ID, a three-byte command would start with a length of `2`, the command ID, and a value.

## Initiate the connection

Once the G4 Host application is running, you should be able to open a TCP/IP connection to port 62222 on the local machine.

```python
import socket

HOST = 'localhost'
PORT = 62222

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    try:
        s.connect((HOST, PORT))
    except ConnectionRefusedError:
        print(f"G4 Host doesn't appear to be running on {HOST}:{PORT}")
    # … commands follow here
```

The code above establishes a tcp connection similar to what creating an instance of the matlab `PanelsController` does:

```matlab
ctlr = PanelsController();
ctlr.open(true);
```

The `PanelsController` is a class that handles the connection on the TCP/IP level. It contains many methods which will handle sending the TCP commands for you.

### Turn all panels on {#all_on}

This command turns all panels on to the brightest level. If the arena is already on, you should not see a change. Use this for checking if your arena works.

This is a two-byte command (notation in hexadecimal): length is set to `0x01` (`1` in integer, `0b00000001` in binary), the command is `0xff` (`255` in decimal, `0b11111111` in binary). The following paragraphs will only use hexadecimal notation of the bytes.

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\xff')
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.allOn();
```

### Turn all panels off {#all_off}

This command turns all panels off. If the arena is already turned off, there will be no change.

This is a two-byte command with the length `0x01` and the command `0x00`.

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\x00')
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.allOff();
```

### Stop Display {#stop_display}

This command deactivates the display.

This is a two-byte command with the length `0x01` and the command `0x30`.

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\x30')
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.stopDisplay();
```

### Reset Display {#reset_display}

Reset the display. All panels will be off.

This is a two-byte command with the length byte `0x01` and the command `0x01`.

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\x01')
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.sendDisplayReset();
```

### Reset Panel {#reset}

Reset a single panel.

This is a three-byte command with the length `0x02`, the command `0x01`, and the third byte representing the address of the panel.

```python
    # … initiate the connection (see above)
    panel_number = 2
    s.sendall(b'\x01\x01' + bytes([panel_number]))
```

The corresponding MATLAB code:

```matlab
% … This is not implemented in PanelsController
```

### Controller reset {#ctr_reset}

This is a two-byte command with the length `0x01` and the command `0x60`.

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\x60')
```

The corresponding MATLAB code:

```matlab
% … This is not implemented in PanelsController
```

### Get Version {#get_version}

This is a two-byte command with the length `0x01` and the command `0x46`. It returns the version and Panel_com logs this to the error log file.

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\x46')
    # … add code to read data, eg:
    rsp = s.recv(1024)
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.getVersion();
```

### Reset Counter {#reset_counter}

This is a two-byte command with the length `0x01` and the command `0x42`.

__Note__: This command is currently not used. TODO: Explain usage.
{:.warning}

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\x42')
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.resetCounter();
```

### Request Treadmill Data {#request_treadmill_data}

This is a two-byte command with the length `0x01` and the command `0x45`.

__Note__: This command is currently not used. TODO: Explain usage.
{:.warning}

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\x45')
```

The corresponding MATLAB code:

```matlab
% … This is not implemented in PanelsController

```

### Update GUI Info {#update_gui_info}

This is a two-byte command with the length `0x01` and the command `0x19`.

__Note__: This is supposed to update gain, offset, and position information (according to code comments). __TODO__: Explain usage.
{:.warning}

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\x19')
```

The corresponding MATLAB code:

```matlab
% … This is not implemented in PanelsController

```

### Start Log {#start_log}

Sending this command starts the logging process. The data is logged directly from the IO card and into the TDMS file format (see [data handling](data-handling.md)).

This is a two-byte command with the length `0x01` and the command `0x41`.

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\x41')
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.startLog();
```

### Stop Log {#stop_log}

Sending this command stops the logging process.

__Note__: This command seems to respond slowly. The MATLAB code has some fallback and potential manual intervention: if the stop_log fails, MATLAB tries again after 100ms. If that still fails, a popup window asks the user to manually stop  the log file. If you use the TCP/IP command, try to use a similar strategy.

This is a two-byte command with the length `0x01` and command `0x40`.

```python
    # … initiate the connection (see above)
    s.sendall(b'\x01\x40')
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.stopLog();
```

### Set Control Mode {#set_control_mode}

This defines the [display mode](protocol-designer_display-modes.md) and requires an argument between 0 and 7.

This is a three-byte command with the length `0x02`, the command `0x10`, and the third byte with the desired control mode. The MATLAB code sends the command in blocking mode, so you might want to set the `MSG_WAITALL` flag in the `sendall` call.

```python
    # … initiate the connection (see above)
    mode = 1
    assert 0 <= mode <= 7, "display mode outside allowed range 0…7"
    s.sendall(b'\x02\x10' + bytes([mode]))
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
mode = 1;
ctlr.setControlMode(mode);
```

### Set active Analog Output Channels {#set_active_ao_channels}

This command activates or deactivates the four possible output channels. The channels are encoded as binary flags, channel 0 for the lowest bit, channel 1 for the second etc… Channel 0 would therefore be `0b00000001`, channels 1 and 3 would be `0b00001010`.

This is a three-byte command with the length `0x02`, the command `0x11`, and the value in the third byte representing the required channels.

```python
    # … initiate the connection (see above)
    ao_channels = 0b0000_0101 # Channel 0 and 2
    assert 0 <= ao_channels < 16, 
        "Wrong AO modes selected. Only 0b0000_0000 to 0b00001111 is allowed."
    s.sendall(b'\x02\x10' + bytes([ao_channels]))
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.setActiveAOChannels(0101); % Only last 4 bits required.
```

### Stream channels {#stream_channels}

The command is used to set the analog input channels.

This is a three-byte command with the length `0x02`, the command `0x13`, and the value in the third byte representing the active channels.

__Note__: TODO: The exact usage is unclear.

```python
    # … initiate the connection (see above)
    channels = 1 # unclear what this represents
    s.sendall(b'\x02\x13' + bytes([channels]))
```

The corresponding MATLAB code:

```matlab
% … This is not yet implemented in PanelsController

```

### Set Pattern ID {#set_pattern_id}

Displays the pattern with the specified ID on the panels.

This is a four-byte command with the length `0x03`, the command `0x03`, and the third and fourth byte defining the address (in little endian).

```python
    # … initiate the connection (see above)
    pattern_id = b'\x05\x05'
    s.sendall(b'\x03\x03' + pattern_id)
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
patID = 1;
ctlr.setPatternID(patID); 
```

### Set Pattern Function ID {#set_pattern_func_id}

Use a the function with the specified ID.

This is a four-byte command with the length `0x03` and the command `0x15`. The use of the third and fourth byte are currently unverified, but most likely they refer to an ID just like the pattern ID.

__TODO__: Verify use of function ID.
{:.warning}

```python
    # … initiate the connection (see above)
    func_pattern_id = b'\x02\x07'
    s.sendall(b'\x03\x15' + func_pattern_id)
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
funcID = 1;
ctlr.setPatternFunctionID(funcID); 
```

### Start Display {#start_display}

Start Display tells the arena to show the currently configured function and pattern for a specified time. The time in the TCP/IP command is specified in tenth of a second.

This is a four-byte command with the length `0x03`, the command `0x21` and the third and fourth representing the time.

```python
    # … initiate the connection (see above)
    duration = 6 * 10  # 60 deciseconds = 6 seconds
    s.sendall(b'\x03\x15' + duration.to_bytes(2, 'little') )
```

The corresponding MATLAB code (internal conversion from second to decisecond):

```matlab
% … initiate the connection (see above)
dur = 6;
ctlr.startDisplay(dur*10); 
```

### Set Framerate {#set_frame_rate}

This four-byte command has a length of `0x03`, command of `0x12`, and sends a little-endian encoded two-byte framerate.

__TODO__: Verify that the framerate is in Hz and only accepts integer numbers? Add description.
{:.warning}

```python
    # … initiate the connection (see above)
    fps = 500
    s.sendall(b'\x03\x12' + fps.to_bytes(2, 'little') )
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.setFrameRate(500); 
```

### Set Position X {#set_position_x}

This four-byte command requires the length byte as `0x03`, the command as `0x70`, and has a little-endian encoded two-byte value for the X-position.

```python
    # … initiate the connection (see above)
    pos_x = 17
    s.sendall(b'\x03\x70' + pos_x.to_bytes(2, 'little') )
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.setPositionX(17); 
```

### Set Position Y {#set_position_y}

This four-byte command requires the length byte as `0x03`, the command as `0x71`, and has a little-endian encoded two-byte value for the Y-position.

```python
    # … initiate the connection (see above)
    pos_y = 10
    s.sendall(b'\x03\x71' + pos_y.to_bytes(2, 'little') )
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.setPositionY(10); 
```

### Set Analog Output Function ID {#set_ao_function_id}

This five-byte command requires the length byte as `0x04`, the command as `0x31`. The third byte represents the analog output channel, a value between 0 and 3. The fourth and fifth byte is the little-endian encoded ID of the function.

```python
    # … initiate the connection (see above)
    chan = 1 # 0…3
    index = 23
    assert 0 <= chan  <= 3, "channel outside range"
    s.sendall(b'\x04\x31' + bytes([chan]) + index.to_bytes(1, 'little'))
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
channel = 1;
ID = 23;
ctlr.setAOFunctionID(channel, ID); 
```

### Set Analog Output {#set_ao}

Set the voltage of a channel to a specified value.

The voltage of a analog output channel is set through two different five-byte TCP/IP commands: the length is `0x04` in both cases, for negative voltages the command is `0x11` and for positive voltages `0x10`. Bytes 4 and 5 encode the actual voltage in a little-endian encoded 16bit integer value. According to the documentation, the maximum voltage of 10V is mapped to 32767 (although the split into two functions would allow higher values for the maximum). In MATLAB, both functions are mapped to the `set_ao` function.

```python
    # … initiate the connection (see above)
    chan = 1 # 0…3
    voltage = 32767 # -32767…0…32767 → -10V…0V…10V
    assert 0 <= chan  <= 3, "channel outside range"
    assert -32767 <= voltage <= 32767, "voltage outside range"
    if voltage < 0:
        s.sendall(b'\x04\x11' + bytes([chan]) + abs(voltage).to_bytes(2, 'little'))
    else:
        s.sendall(b'\x04\x10' + bytes([chan]) + voltage.to_bytes(2, 'little'))
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
channel = 1;
voltage = 32767;
ctlr.setAO(channel, voltage); 
```

### Set Gain Bias {#set_gain_bias}

This six-byte command has a length of `0x05` and a command byte of `0x01`. Bytes 3 and 4 are a little-endian representation of the signed gain value, bytes 5 and 6 of the signed bias value.

```python
    # … initiate the connection (see above)
    gain_x = 100
    bias_x = 200
    s.sendall(b'\x05\x01' +
        gain_x.to_bytes(2, 'little', signed=True) +
        bias_x.to_bytes(2, 'little', signed=True))
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
gain = 100;
bias = 100;
ctlr.setGain(gain, bias); 
```

### Set Pattern and Position Function {#set_pattern_and_position_function}

The six-byte command has a length of `0x05` and uses command `0x05`. Bytes 3 and 4 are used for a little-endian representation of the pattern ID, 5 and 6 of a function ID.

```python
    # … initiate the connection (see above)
    pattern = 5
    position = 37
    s.sendall(b'\x05\x05' +
        pattern.to_bytes(2, 'little') +
        position.to_bytes(2, 'little'))
```

The corresponding MATLAB code:

```matlab
% … This is not implemented in PanelsController

```

### Stream Frame {#stream_frame}

Stream a full frame to the panels.

This command has a variable length and starts with the first byte `0x32`. Bytes 2 and 3 represent the length of the data, which is the length of the data minus seven bytes for the _header_.

__TODO__: Clarify if `x_ao` and `y_ao` specify a value or (more likely) the ID of a function.
{:.warning}

```python
    # … initiate the connection (see above)
    frame_content = b'…' # This is the actual content of the frame
    x_ao = 0
    y_ao = 0
    data_length = len(frame_content)
    s.sendall(b'\x32' +
        data_length.to_bytes(2, 'little'),
        x_ao.to_bytes(2, 'little', signed=True) +
        y_ao.to_bytes(2, 'little', signed=True) +
        frame_content)
```

The corresponding MATLAB code:

```matlab
% … This is not yet implemented in PanelsController

```

### Change Root Directory {#change_root_dir}

Set the root directory where pattern and functions are stored.

This is a variable length command with the first byte `0x43`. Bytes 2 and 3 define the length of the directory name and the following  bytes contain the directory name.

```python
    # … initiate the connection (see above)
    root_directory_name = 'C:\my path to the patterns' # actual path
    root_dir = root_directory_name.encode('utf-8')
    dir_length = len(root_dir)
    s.sendall(b'\x43' +
        dir_length.to_bytes(2, 'little'),
        root_dir)
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
ctlr.setRootDirectory("C:\\my path to the patterns");
```

### Combined Command {#combined_command}

This 19-byte command sends several settings at once. The length is set as `0x12` (=18) and the command ID is `0x07`. The third byte represents the display mode and the following pairs of bytes represents IDs of pattern, function, and the four AO functions. This is followed by two bytes for the frame rate and two bytes for the duration in tenth of a second.

__Info__: This command is relatively new and mostly untested. The [`G4_run_protocol_combinedCommand.m`](https://github.com/JaneliaSciComp/G4_Display_Tools/blob/master/G4_Protocol_Designer/run_protocols/G4_run_protocol_combinedCommand.m) used this, but apparently there were some timing issues. Needs more exploration.
{:.warning}

```python
    # … initiate the connection (see above)
    display_mode = 1
    pattern_id = 27
    function_id = 11
    ao1_id = 25
    ao2_id = 0
    ao3_id = 1512
    ao4_id = 0
    fps = 500
    duration = 6 * 10 # in deciseconds
    s.sendall(b'\x12\x07' +
        display_mode.to_bytes(1, 'little') + 
        pattern_id.to_bytes(2, 'little') +
        function_id.to_bytes(2, 'little') +
        ao1_id.to_bytes(2, 'little') +
        ao2_id.to_bytes(2, 'little') +
        ao3_id.to_bytes(2, 'little') +
        ao4_id.to_bytes(2, 'little') +
        fps.to_bytes(2, 'little') +
        duration.to_bytes(2, 'little')
        )
```

The corresponding MATLAB code:

```matlab
% … initiate the connection (see above)
mode = 1;
patternID = 27;
functionID = 11;
ao0ID = 0;
ao1ID = 15;
ao2ID = 0;
ao3ID = 12;
fps = 500;
deciSeconds = 6;
ctlr.combinedCommand(mode, patternID, functionID, ao0ID, ao1ID, ao2ID, ao3ID, fps, deciSeconds);
```

### Set panels controller parameters

Additionally, in `PanelsController` there is a command with which to set all parameters at once.

The MATLAB code: 

```matlab
% … initiate the connection (see above)
p = {mode, patternID, gain, offset, functionID, fps, frameIndex, activeAOchannels, aoIndices};
ctlr.setControllerParameters(p);
```
