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

// --- Helper: Get config file path in ~/.config/phonorama/ ---
/**
 * get_config_path - Fills buf with the full path to the config file.
 * Ensures the config directory exists.
 */
void get_config_path(char *buf, size_t buflen) {
    const char *home = getenv("HOME");
    if (!home) home = ".";
    // Ensure the config directory exists
    char dir[512];
    snprintf(dir, sizeof(dir), "%s/.config/phonorama", home);
    mkdir(dir, 0755); // Ignore error if already exists
    // Build the full config file path
    snprintf(buf, buflen, "%s/.config/phonorama/phonorama_config.json", home);
}

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
    cfg->monitor_enabled = true;
}

// --- Load configuration from file (returns true if successful) ---
bool config_load(Config *cfg) {
    char config_path[512];
    get_config_path(config_path, sizeof(config_path));
    FILE *f = fopen(config_path, "r");
    if (!f) return false;
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "\"input_channel\""))
            sscanf(line, " \"input_channel\" : %hhu,", &cfg->input_channel);
        else if (strstr(line, "\"input_l\""))
            sscanf(line, " \"input_l\" : %d,", &cfg->input_l);
        else if (strstr(line, "\"input_r\""))
            sscanf(line, " \"input_r\" : %d,", &cfg->input_r);
        else if (strstr(line, "\"output_l\""))
            sscanf(line, " \"output_l\" : %d,", &cfg->output_l);
        else if (strstr(line, "\"output_r\""))
            sscanf(line, " \"output_r\" : %d,", &cfg->output_r);
        else if (strstr(line, "\"headphone_enabled\"")) {
            int val;
            sscanf(line, " \"headphone_enabled\" : %d,", &val);
            cfg->headphone_enabled = (val != 0);
        } else if (strstr(line, "\"monitor_enabled\"")) {
            int val;
            sscanf(line, " \"monitor_enabled\" : %d", &val);
            cfg->monitor_enabled = (val != 0);
        }
    }
    fclose(f);
    return true;
}

// --- Save configuration to file (returns true if successful) ---
bool config_save(const Config *cfg) {
    char config_path[512];
    get_config_path(config_path, sizeof(config_path));
    FILE *f = fopen(config_path, "w");
    if (!f) return false;
    fprintf(f,
        "{\n"
        "  \"input_channel\" : %d,\n"
        "  \"input_l\" : %d,\n"
        "  \"input_r\" : %d,\n"
        "  \"output_l\" : %d,\n"
        "  \"output_r\" : %d,\n"
        "  \"headphone_enabled\" : %d,\n"
        "  \"monitor_enabled\" : %d\n"
        "}\n",
        cfg->input_channel,
        cfg->input_l,
        cfg->input_r,
        cfg->output_l,
        cfg->output_r,
        cfg->headphone_enabled ? 1 : 0,
        cfg->monitor_enabled ? 1 : 0
    );
    fclose(f);
    return true;
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

    bool verbose = false;

    // Initialize HID device and configuration
    hid_device *hiddev;
    USB_GPIO_DATA gpio_data;
    Config cfg;

    // Load configuration (set defaults only if loading fails)
    if (!config_load(&cfg)) {
        config_set_defaults(&cfg);
    }

    // Command-line option flags and input selection
    bool do_c = false, do_i = false, do_I = false, do_m = false, do_default = false;
    char selected_input[16] = "line";

    // --- Command-line argument parsing ---
    int opt;
    while ((opt = getopt(argc, argv, "c:hiIdl:r:L:R:Mmev")) != -1) {
        switch (opt) {
            case 'e':
                return enumerate_devices();
            case 'c':
                do_c = true;
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
            case 'i': do_i = true; cfg.headphone_enabled = true; break;
            case 'I': do_I = true; cfg.headphone_enabled = false; break;
            case 'd': do_default = true; config_set_defaults(&cfg); break;
            case 'l': cfg.input_l = atoi(optarg); if(cfg.input_l > 127) cfg.input_l = 127; break;
            case 'r': cfg.input_r = atoi(optarg); if(cfg.input_r > 127) cfg.input_r = 127; break;
            case 'L': cfg.output_l = atoi(optarg); if(cfg.output_l > 145) cfg.output_l = 145; break;
            case 'R': cfg.output_r = atoi(optarg); if(cfg.output_r > 145) cfg.output_r = 145; break;
            case 'M': do_m = true; cfg.monitor_enabled = true; break;
            case 'm': do_m = false; cfg.monitor_enabled = false; break;
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
    if (do_c || do_default) {
        // For mute: do not send channel switch, just set mute GPIO
        if (strcmp(selected_input, "mute") != 0) {
            send(hiddev, 0x2a, cfg.input_channel);
            if (cfg.input_channel == 0x1) {
                gpio_data.ucGpioCtrl = 0x7F;
                gpio_data.ucGpioOut = 0x2;
            } else if (cfg.input_channel == 0x8) {
                gpio_data.ucGpioCtrl = 0x7F;
                gpio_data.ucGpioOut = (strcmp(selected_input, "mc") == 0) ? 0x45 : 0x00;
            }
        } else {
            gpio_data.ucGpioCtrl = 0x7F;
            gpio_data.ucGpioOut = 0x2;
        }
        send_gpio(hiddev, &gpio_data);
    }

    // --- Headphone enable/disable logic ---
    if (do_i || cfg.headphone_enabled)
        send(hiddev, 0x1a, 0x00);
    if (do_I || !cfg.headphone_enabled)
        send(hiddev, 0x1a, 0x01);

    // --- Input monitoring logic ---
    send(hiddev, 0x2c, cfg.monitor_enabled ? 0x05 : 0x01);

    // --- Volume control logic ---
    if (cfg.input_l > 0) send(hiddev, 0x1c, cfg.input_l + 104);
    if (cfg.input_r > 0) send(hiddev, 0x1e, cfg.input_r + 104);
    if (cfg.output_l > 0) send(hiddev, 0x07, cfg.output_l + 110);
    if (cfg.output_r > 0) send(hiddev, 0x09, cfg.output_r + 110);

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

    if (!config_save(&cfg))
        printf("Warning: Failed to save config\n");
    return 0;
}