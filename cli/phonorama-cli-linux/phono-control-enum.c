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

typedef unsigned char BYTE;
typedef unsigned char UCHAR;

typedef struct {
    UCHAR ucGpioCtrl;
    UCHAR ucGpioOut;
    UCHAR ucSpdifTxCtrl_0;
    UCHAR ucSpdifTxCtrl_1;
    UCHAR ucSpdifTxCtrl_2;
} USB_GPIO_DATA, *PUSB_GPIO_DATA;

typedef struct {
    unsigned char input_channel;
    int input_l;
    int input_r;
    int output_l;
    int output_r;
    bool headphone_enabled;
    bool monitor_enabled;
} Config;

void config_set_defaults(Config *cfg) {
    cfg->input_channel = 0x1;
    cfg->input_l = 86;
    cfg->input_r = 86;
    cfg->output_l = 145;
    cfg->output_r = 145;
    cfg->headphone_enabled = true;
    cfg->monitor_enabled = true;
}

bool config_load(Config *cfg) {
    FILE *f = fopen(CONFIG_FILE, "r");
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
    printf("  -e [--verbose]          - Enumerate matching HID devices\n");
    printf("  -h                      - Show this help message\n");
}

int enumerate_devices(bool verbose) {
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
        if (verbose) {
            printf("  Manufacturer: %ls\n", cur->manufacturer_string);
            printf("  Product:      %ls\n", cur->product_string);
            printf("  Serial:       %ls\n", cur->serial_number);
        }
        found++;
        cur = cur->next;
    }

    hid_free_enumeration(devs);
    hid_exit();

    if (found == 0)
        printf("No matching HID devices found.\n");

    return 0;
}

int main(int argc, char *argv[]) {
    hid_device *hiddev;
    USB_GPIO_DATA gpio_data;
    Config cfg;

    config_set_defaults(&cfg);
    config_load(&cfg);

    bool do_c = false, do_i = false, do_I = false, do_m = false, do_default = false;
    char selected_input[4] = "line";
    bool verbose_mode = false;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--verbose") == 0)
            verbose_mode = true;
    }

    int opt;
    while ((opt = getopt(argc, argv, "c:hiIdl:r:L:R:Mme")) != -1) {
        switch (opt) {
            case 'e':
                return enumerate_devices(verbose_mode);
            case 'c':
                do_c = true;
                for (char *p = optarg; *p; ++p) *p = tolower(*p);
                strcpy(selected_input, optarg);
                if (strcmp(optarg, "line") == 0)
                    cfg.input_channel = 0x1;
                else if (strcmp(optarg, "mc") == 0 || strcmp(optarg, "mm") == 0)
                    cfg.input_channel = 0x8;
                else if (strcmp(optarg, "mute") == 0)
                    cfg.input_channel = 0xC1;
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
            case 'h': print_help(); return 0;
            default: print_help(); return 1;
        }
    }

    if (hid_init() != 0) {
        printf("Failed to initialize HID library\n");
        return -1;
    }

    hiddev = hid_open(VENDOR_ID, PRODUCT_ID, NULL);
    if (!hiddev) {
        printf("Unable to open the HID device\n");
        return -1;
    }

    printf("Device opened successfully.\n");

    memset(&gpio_data, 0, sizeof(gpio_data));

    if (do_c || do_default) {
        send(hiddev, 0x2a, cfg.input_channel);
        if (cfg.input_channel == 0x1) {
            gpio_data.ucGpioCtrl = 0x7F;
            gpio_data.ucGpioOut = 0x2;
        } else if (cfg.input_channel == 0x8) {
            gpio_data.ucGpioCtrl = 0x7F;
            gpio_data.ucGpioOut = (strcmp(selected_input, "mc") == 0) ? 0x45 : 0x00;
        } else if (cfg.input_channel == 0xC1) {
            gpio_data.ucGpioCtrl = 0x7F;
            gpio_data.ucGpioOut = 0x2;
        }
        send_gpio(hiddev, &gpio_data);
    }

    if (do_i || cfg.headphone_enabled)
        send(hiddev, 0x1a, 0x00);
    if (do_I || !cfg.headphone_enabled)
        send(hiddev, 0x1a, 0x01);

    send(hiddev, 0x2c, cfg.monitor_enabled ? 0x05 : 0x01);

    if (cfg.input_l > 0) send(hiddev, 0x1c, cfg.input_l + 104);
    if (cfg.input_r > 0) send(hiddev, 0x1e, cfg.input_r + 104);
    if (cfg.output_l > 0) send(hiddev, 0x07, cfg.output_l + 110);
    if (cfg.output_r > 0) send(hiddev, 0x09, cfg.output_r + 110);

    hid_close(hiddev);
    hid_exit();

    if (!config_save(&cfg))
        printf("Warning: Failed to save config\n");

    return 0;
}
