// phono-control: Command-line utility for controlling ESI Phonorama device via HID
// Stores persistent configuration in ~/.config/phonorama/phonorama_config.json

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <hidapi/hidapi.h>
#include <unistd.h>
#include <stdbool.h>
#include <sys/stat.h> // For mkdir

// --- Device and config constants ---
#define VENDOR_ID  0x2573
#define PRODUCT_ID 0x0001

// --- Type definitions for device communication ---
typedef unsigned char BYTE;
typedef unsigned char UCHAR;

typedef struct {
    UCHAR ucGpioCtrl;
    UCHAR ucGpioOut;
    UCHAR ucSpdifTxCtrl_0;
    UCHAR ucSpdifTxCtrl_1;
    UCHAR ucSpdifTxCtrl_2;
} USB_GPIO_DATA, *PUSB_GPIO_DATA;

// --- Persistent configuration structure ---
typedef struct {
    unsigned char input_channel;
    int input_l;
    int input_r;
    int output_l;
    int output_r;
    bool headphone_enabled;
    bool monitor_enabled;
} Config;

// --- Set default configuration values ---
void config_set_defaults(Config *cfg) {
    cfg->input_channel = 0x1;
    cfg->input_l = 86;
    cfg->input_r = 86;
    cfg->output_l = 145;
    cfg->output_r = 145;
    cfg->headphone_enabled = true;
    cfg->monitor_enabled = false;
}

// --- Send GPIO data to device ---
void send_gpio(hid_device *dev, PUSB_GPIO_DATA gpio_data) {
    unsigned char buf[32] = {0};
    buf[22] = 0x01;
    buf[23] = gpio_data->ucGpioCtrl;
    buf[24] = gpio_data->ucGpioOut;
    buf[25] = gpio_data->ucSpdifTxCtrl_0;
    buf[26] = gpio_data->ucSpdifTxCtrl_1;
    buf[27] = gpio_data->ucSpdifTxCtrl_2;
    int res = hid_write(dev, buf, sizeof(buf));
    if (res < 0)
        printf("ERROR: Failed to send GPIO data: %d\n", res);
}

// --- Send a command to the device and read response ---
int send(hid_device *dev, unsigned char op, unsigned char byte) {
    unsigned char buf[33] = {0};
    buf[1] = 0x12;
    buf[2] = 0x34;
    buf[3] = op;
    buf[5] = 1;
    buf[6] = byte;
    buf[22] = 0x80;
    int res = hid_write(dev, buf, sizeof(buf));
    if (res < 0) {
        printf("ERROR: Operation failed: %d\n", res);
        return res;
    }
    return hid_read(dev, buf, sizeof(buf));
}

// --- Print help text ---
void print_help() {
    printf("Usage: phono-control [options]\n\n");
    printf("Options:\n");
    printf("  -c <line|MC|MM|mute>   - Set input channel\n");
    printf("  -l <0-127>              - Set input left volume\n");
    printf("  -r <0-127>              - Set input right volume\n");
    printf("  -L <0-145>              - Set output left volume\n");
    printf("  -R <0-145>              - Set output right volume\n");
    printf("  -i                      - Enable headphone\n");
    printf("  -I                      - Disable headphone\n");
    printf("  -M                      - Enable input monitoring\n");
    printf("  -m                      - Disable input monitoring\n");
    printf("  -d                      - Reset all to defaults\n");
    printf("  -e                      - Enumerate matching HID devices (shows detailed info)\n");
    printf("  -h                      - Show this help message\n");
}

// --- Enumerate matching HID devices ---
int enumerate_devices() {
    struct hid_device_info *devs, *cur;
    int found = 0;
    if (hid_init() != 0) {
        fprintf(stderr, "ERROR: HID init failed\n");
        return 1;
    }
    devs = hid_enumerate(VENDOR_ID, PRODUCT_ID);
    cur = devs;
    while (cur) {
        printf("Device found: %s\n", cur->path);
        printf("  Vendor ID   : %04hx\n", cur->vendor_id);
        printf("  Product ID  : %04hx\n", cur->product_id);
        printf("  Manufacturer: %ls\n", cur->manufacturer_string ? cur->manufacturer_string : L"(none)");
        printf("  Product     : %ls\n", cur->product_string ? cur->product_string : L"(none)");
        if (cur->serial_number && wcslen(cur->serial_number) > 0)
            printf("  Serial      : %ls\n", cur->serial_number);
        else
            printf("  Serial      : Unknown\n");
        found++;
        cur = cur->next;
    }
    hid_free_enumeration(devs);
    hid_exit();
    if (found == 0)
        printf("No matching HID devices found.\n");
    return 0;
}

// --- Main program logic ---
int main(int argc, char *argv[]) {
    // Print the full command line used to invoke this program
    printf("phono-control");
    for (int i = 1; i < argc; ++i) {
        printf(" %s", argv[i]);
    }
    printf("\n");
    
    bool set_input_l = false, set_input_r = false, set_output_l = false, set_output_r = false;
    bool set_monitor = false; 
    bool verbose = false;

    // Initialize HID device and configuration
    hid_device *hiddev;
    USB_GPIO_DATA gpio_data;
    Config cfg;

    // Command-line option flags and input selection
    bool set_channel = false;
    bool set_headphone = false;
    bool set_headphone_off = false;
    bool set_default = false;
    char selected_input[16] = "line";

    // --- Command-line argument parsing ---
    int opt;
    while ((opt = getopt(argc, argv, "c:hiIdl:r:L:R:Mmev")) != -1) {
        switch (opt) {
            case 'e':
                return enumerate_devices();
            case 'c': set_channel = true;
                // Normalize input string to lowercase
                for (char *p = optarg; *p; ++p) *p = tolower(*p);
                strcpy(selected_input, optarg);
                // Set input channel code based on user selection
                if (strcmp(optarg, "line") == 0)
                    cfg.input_channel = 0x1;
                else if (strcmp(optarg, "mc") == 0 || strcmp(optarg, "mm") == 0)
                    cfg.input_channel = 0x8;
                else if (strcmp(optarg, "mute") == 0)
                    cfg.input_channel = 0xC1; // Special value for mute
                break;
            case 'i': set_headphone = true; cfg.headphone_enabled = true; break;
            case 'I': set_headphone_off = true; cfg.headphone_enabled = false; break;
            case 'd': set_default = true; config_set_defaults(&cfg); break;
            case 'l': cfg.input_l = atoi(optarg); set_input_l = true; break;
            case 'r': cfg.input_r = atoi(optarg); set_input_r = true; break;
            case 'L': cfg.output_l = atoi(optarg); set_output_l = true; break;
            case 'R': cfg.output_r = atoi(optarg); set_output_r = true; break;  
            case 'M': set_monitor = true; cfg.monitor_enabled = true; break;
            case 'm': set_monitor = true; cfg.monitor_enabled = false; break;
            case 'v': verbose = true; break;
            case 'h': print_help(); return 0;
            default: print_help(); return 1;
        }
    }

    // --- HID device initialization ---
    if (hid_init() != 0) {
        printf("Failed to initialize HID library\n");
        return -1;
    }

    hiddev = hid_open(VENDOR_ID, PRODUCT_ID, NULL);
    if (!hiddev) {
        printf("Unable to open the HID device\n");
        return -1;
    }

    memset(&gpio_data, 0, sizeof(gpio_data));

    // --- Input channel and mute logic ---
    if (set_channel || set_default) {
        if (strcmp(selected_input, "mute") != 0) {
            // Normal input channel selection
            send(hiddev, 0x2a, cfg.input_channel);
            if (cfg.input_channel == 0x1) {
                gpio_data.ucGpioCtrl = 0x7F;
                gpio_data.ucGpioOut = 0x2;
            } else if (cfg.input_channel == 0x8) {
                gpio_data.ucGpioCtrl = 0x7F;
                gpio_data.ucGpioOut = (strcmp(selected_input, "mc") == 0) ? 0x45 : 0x00;
            }
        } else {
            // --- SEND THE MUTE COMMAND ---
            send(hiddev, 0x2a, cfg.input_channel); // 0xC1 for mute
                gpio_data.ucGpioCtrl = 0x7F;
                gpio_data.ucGpioOut = 0x2;
    }
    send_gpio(hiddev, &gpio_data);

   if (set_default) {
    send_gpio(hiddev, &gpio_data);
    usleep(50000); // 50 ms delay
    send(hiddev, 0x2c, cfg.monitor_enabled ? 0x05 : 0x01); // Set monitoring to default state

    // --- Send all default values to device ---
    send(hiddev, 0x2a, cfg.input_channel); // Default input channel
    send(hiddev, 0x1c, cfg.input_l + 104);      // Default input left
    send(hiddev, 0x1e, cfg.input_r + 104);      // Default input right
    send(hiddev, 0x07, cfg.output_l + 110); // Default output left (with offset)
    send(hiddev, 0x09, cfg.output_r + 110); // Default output right (with offset)
    send(hiddev, 0x1a, cfg.headphone_enabled ? 0x00 : 0x01); // Headphone state
    }
}

    // --- Headphone enable/disable logic ---
    if (set_headphone)
    send(hiddev, 0x1a, 0x00);
    if (set_headphone_off)
    send(hiddev, 0x1a, 0x01);

    // --- Input monitoring logic ---
    if (set_monitor) {
    send(hiddev, 0x2c, cfg.monitor_enabled ? 0x05 : 0x01);
    }

    // --- Volume control logic: only send if explicitly set ---
    if (set_input_l) send(hiddev, 0x1c, cfg.input_l + 104);
    if (set_input_r) send(hiddev, 0x1e, cfg.input_r + 104);
    if (set_output_l) send(hiddev, 0x07, cfg.output_l + 110);
    if (set_output_r) send(hiddev, 0x09, cfg.output_r + 110);

    // --- Verbose summary block ---
    if (verbose) {
        printf("---- Verbose Output ----\n");
        printf("Input channel: 0x%x (%s)\n", cfg.input_channel, selected_input);
        printf("Input L: %d\n", cfg.input_l);
        printf("Input R: %d\n", cfg.input_r);
        printf("Output L: %d\n", cfg.output_l);
        printf("Output R: %d\n", cfg.output_r);
        printf("Headphone: %s\n", cfg.headphone_enabled ? "Enabled" : "Disabled");
        printf("Monitor: %s\n", cfg.monitor_enabled ? "Enabled" : "Disabled");
        printf("------------------------\n");
    }

    // --- Cleanup and save config ---
    hid_close(hiddev);
    hid_exit();

    return 0;
} 