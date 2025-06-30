#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <hidapi/hidapi.h>
#include <unistd.h>
#include <stdbool.h>

#define VENDOR_ID  0x2573
#define PRODUCT_ID 0x0001
#define CONFIG_FILE "phonorama_config.json"

// Typedefs for compatible types
typedef unsigned char BYTE;
typedef unsigned char UCHAR;

typedef struct {
    UCHAR ucGpioCtrl;
    UCHAR ucGpioOut;
    UCHAR ucSpdifTxCtrl_0;
    UCHAR ucSpdifTxCtrl_1;
    UCHAR ucSpdifTxCtrl_2;
} USB_GPIO_DATA, *PUSB_GPIO_DATA;

// Config structure
typedef struct {
    unsigned char input_channel;
    int input_l;
    int input_r;
    int output_l;
    int output_r;
    bool headphone_enabled;
    bool monitor_enabled;
} Config;

// Set default config values
void config_set_defaults(Config *cfg) {
    cfg->input_channel = 0x1;  // line
    cfg->input_l = 86;
    cfg->input_r = 86;
    cfg->output_l = 145;
    cfg->output_r = 145;
    cfg->headphone_enabled = true;
    cfg->monitor_enabled = true;
}

// Minimal JSON load (very simple, no error checking)
bool config_load(Config *cfg) {
    FILE *f = fopen(CONFIG_FILE, "r");
    if (!f) return false;

    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "\"input_channel\"")) {
            sscanf(line, " \"input_channel\" : %hhu,", &cfg->input_channel);
        } else if (strstr(line, "\"input_l\"")) {
            sscanf(line, " \"input_l\" : %d,", &cfg->input_l);
        } else if (strstr(line, "\"input_r\"")) {
            sscanf(line, " \"input_r\" : %d,", &cfg->input_r);
        } else if (strstr(line, "\"output_l\"")) {
            sscanf(line, " \"output_l\" : %d,", &cfg->output_l);
        } else if (strstr(line, "\"output_r\"")) {
            sscanf(line, " \"output_r\" : %d,", &cfg->output_r);
        } else if (strstr(line, "\"headphone_enabled\"")) {
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

// Save config to JSON file (simple formatting)
bool config_save(const Config *cfg) {
    FILE *f = fopen(CONFIG_FILE, "w");
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

// Function for sending GPIO data
void send_gpio(hid_device *dev, PUSB_GPIO_DATA gpio_data)
{
    unsigned char buf[32];
    memset(buf, 0, sizeof(buf));

    buf[22] = 0x01;  // GPIO
    buf[23] = gpio_data->ucGpioCtrl;
    buf[24] = gpio_data->ucGpioOut;
    buf[25] = gpio_data->ucSpdifTxCtrl_0;
    buf[26] = gpio_data->ucSpdifTxCtrl_1;
    buf[27] = gpio_data->ucSpdifTxCtrl_2;

    int res = hid_write(dev, buf, sizeof(buf));
    if (res < 0) {
        printf("ERROR: Failed to send GPIO data: %d\n", res);
    }
}

// Send function for HID commands
int send(hid_device *dev, unsigned char op, unsigned char byte)
{
    unsigned char buf[33];  // 32 bytes + report ID
    memset(buf, 0, sizeof(buf));
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

// Print help message with all options
void print_help() {
    printf("Usage: phono-control [options]\n\n");
    printf("Options:\n");
    printf("  -c <line|MC|MM|mute>   - Set input channel (line, MC, MM, mute)\n");
    printf("  -h                      - Show this help message\n");
    printf("  -i                      - Enable headphone\n");
    printf("  -I                      - Disable headphone\n");
    printf("  -d                      - Set default values for input/output channels\n");
    printf("  -l <0-127>              - Set input left volume\n");
    printf("  -r <0-127>              - Set input right volume\n");
    printf("  -L <0-145>              - Set output left volume\n");
    printf("  -R <0-145>              - Set output right volume\n");
    printf("  -M                      - Enable input monitoring\n");
    printf("  -m                      - Disable input monitoring\n");
    printf("  -s                      - Show current config settings and exit\n");
}

// Main function
int main(int argc, char *argv[])
{
    hid_device *hiddev;
    USB_GPIO_DATA gpio_data;

    Config cfg;
    config_set_defaults(&cfg);
    config_load(&cfg);  // Load saved config, if any

    bool do_c = false, do_i = false, do_disable_headphone = false, do_m = false, do_default = false;
    bool do_status = false;

    int opt;
    while ((opt = getopt(argc, argv, "c:hiIdl:r:L:R:Mm s")) != -1) {
        switch (opt) {
        case 'c':
            do_c = true;
            for (char *p = optarg; *p; ++p) *p = tolower(*p);
            if (strcmp(optarg, "line") == 0)
                cfg.input_channel = 0x1;
            else if (strcmp(optarg, "mc") == 0 || strcmp(optarg, "mm") == 0)
                cfg.input_channel = 0x8;
            else if (strcmp(optarg, "mute") == 0)
                cfg.input_channel = 0xC1;
            break;
        case 'i':
            do_i = true;
            cfg.headphone_enabled = true;
            break;
        case 'I':
            do_disable_headphone = true;
            cfg.headphone_enabled = false;
            break;
        case 'd':
            do_default = true;
            config_set_defaults(&cfg);
            break;
        case 'l':
            cfg.input_l = atoi(optarg);
            if(cfg.input_l < 0) cfg.input_l = 0;
            else if(cfg.input_l > 127) cfg.input_l = 127;
            break;
        case 'r':
            cfg.input_r = atoi(optarg);
            if(cfg.input_r < 0) cfg.input_r = 0;
            else if(cfg.input_r > 127) cfg.input_r = 127;
            break;
        case 'L':
            cfg.output_l = atoi(optarg);
            if(cfg.output_l < 0) cfg.output_l = 0;
            else if(cfg.output_l > 145) cfg.output_l = 145;
            break;
        case 'R':
            cfg.output_r = atoi(optarg);
            if(cfg.output_r < 0) cfg.output_r = 0;
            else if(cfg.output_r > 145) cfg.output_r = 145;
            break;
        case 'M':
            do_m = true;
            cfg.monitor_enabled = true;
            break;
        case 'm':
            do_m = false;
            cfg.monitor_enabled = false;
            break;
        case 's':
            do_status = true;
            break;
        case 'h':
            print_help();
            return 0;
        default:
            print_help();
            return 1;
        }
    }

    if (do_status) {
        printf("Current configuration:\n");
        printf("  Input channel: 0x%x\n", cfg.input_channel);
        printf("  Input left volume: %d\n", cfg.input_l);
        printf("  Input right volume: %d\n", cfg.input_r);
        printf("  Output left volume: %d\n", cfg.output_l);
        printf("  Output right volume: %d\n", cfg.output_r);
        printf("  Headphone enabled: %s\n", cfg.headphone_enabled ? "Yes" : "No");
        printf("  Monitor enabled: %s\n", cfg.monitor_enabled ? "Yes" : "No");
        return 0;
    }

    // Open device
    hiddev = hid_open(VENDOR_ID, PRODUCT_ID, NULL);
    if (!hiddev) {
        fprintf(stderr, "Failed to open device\n");
        return 1;
    }

    // Build gpio_data from cfg
    gpio_data.ucGpioCtrl = 0xFF;  // Assuming default control bits

    // Input channel bits
    gpio_data.ucGpioOut = cfg.input_channel;

    // Set input volume in spdifTxCtrl registers (example mapping)
    gpio_data.ucSpdifTxCtrl_0 = (unsigned char)cfg.input_l;
    gpio_data.ucSpdifTxCtrl_1 = (unsigned char)cfg.input_r;

    // Assume output volume affects GPIO bits or similar - this will depend on device spec
    gpio_data.ucSpdifTxCtrl_2 = (unsigned char)(cfg.output_l & 0xFF);

    // Send the GPIO data to the device
    send_gpio(hiddev, &gpio_data);

    // Save updated config
    if (!config_save(&cfg)) {
        fprintf(stderr, "Warning: Failed to save configuration\n");
    }

    hid_close(hiddev);
    hid_exit();

    return 0;
}
