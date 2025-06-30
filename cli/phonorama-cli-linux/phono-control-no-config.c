#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <hidapi/hidapi.h>
#include <unistd.h>
#include <stdbool.h>

#define VENDOR_ID  0x2573
#define PRODUCT_ID 0x0001

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
}

// Function to handle command line options
int main(int argc, char *argv[])
{
    hid_device *hiddev;
    USB_GPIO_DATA gpio_data;
    bool do_c = false, do_i = false, do_disable_headphone = false, do_m = false;
    unsigned char input_channel = 0x1;  // Default to line
    int input_l = 86, input_r = 86, output_l = 145, output_r = 145;

    // Parsing command line arguments
    int opt;
    while ((opt = getopt(argc, argv, "c:hiIdl:r:L:R:Mm")) != -1) {
        switch (opt) {
        case 'c':
            do_c = true;
            for (char *p = optarg; *p; ++p) *p = tolower(*p);
            if (strcmp(optarg, "line") == 0)
                input_channel = 0x1;
            else if (strcmp(optarg, "mc") == 0 || strcmp(optarg, "mm") == 0)
                input_channel = 0x8;
            else if (strcmp(optarg, "mute") == 0)
                input_channel = 0xC1;
            break;
        case 'i':
            do_i = true;
            break;
        case 'I':
            do_disable_headphone = true;
            break;
        case 'd':
            do_i = true;
            do_c = true;
            do_m = true;
            break;
        case 'l':
            input_l = atoi(optarg);
            input_l = input_l < 0 ? 0 : (input_l > 127 ? 127 : input_l);
            break;
        case 'r':
            input_r = atoi(optarg);
            input_r = input_r < 0 ? 0 : (input_r > 127 ? 127 : input_r);
            break;
        case 'L':
            output_l = atoi(optarg);
            output_l = output_l < 0 ? 0 : (output_l > 145 ? 145 : output_l);
            break;
        case 'R':
            output_r = atoi(optarg);
            output_r = output_r < 0 ? 0 : (output_r > 145 ? 145 : output_r);
            break;
        case 'M':
            do_m = true;
            break;
        case 'm':
            do_m = false;
            break;
        case 'h':
            print_help();
            return 0;
        default:
            print_help();
            return 1;
        }
    }

    // Initializing HID
    if (hid_init() != 0) {
        printf("Failed to initialize HID library\n");
        return -1;
    }

    // Open the device
    hiddev = hid_open(VENDOR_ID, PRODUCT_ID, NULL);
    if (hiddev != NULL) {
        printf("Device opened successfully.\n");

        // Send all changes at once, preserving state
        memset(&gpio_data, 0, sizeof(gpio_data));

        if (do_c) {
            // Set input channel
            printf("Setting input channel: 0x%x\n", input_channel);
            send(hiddev, 0x2a, input_channel);  // Send input channel command

            // Set GPIO data based on input channel
            if (input_channel == 0x1) {  // 'line'
                gpio_data.ucGpioCtrl = 0x7F;
                gpio_data.ucGpioOut = 0x2;  // GPIO data for line
            } else if (input_channel == 0x8) {  // 'MC' or 'MM'
                gpio_data.ucGpioCtrl = 0x7F;
                gpio_data.ucGpioOut = 0x45;  // GPIO data for MC/MM
            } else if (input_channel == 0xC1) {  // 'mute'
                gpio_data.ucGpioCtrl = 0x7F;
                gpio_data.ucGpioOut = 0x2;  // Keep GPIO as if line input
            }
            send_gpio(hiddev, &gpio_data);  // Send GPIO data
        }

        // Send other settings (headphone enable/disable, monitoring, etc.)
        if (do_i) {
            printf("Enabling headphone\n");
            send(hiddev, 0x1a, 0x00);
        }
        if (do_disable_headphone) {
            printf("Disabling headphone\n");
            send(hiddev, 0x1a, 0x01);
        }

        if (do_m) {
            printf("Setting monitor: enable\n");
            send(hiddev, 0x2c, 0x05);
        } else {
            printf("Setting monitor: disable\n");
            send(hiddev, 0x2c, 0x01);
        }

        // Send volume settings
        if (input_l > 0) {
            printf("Setting input left volume: %d\n", input_l);
            send(hiddev, 0x1c, input_l + 104);  // Adjusting volume offset
        }

        if (input_r > 0) {
            printf("Setting input right volume: %d\n", input_r);
            send(hiddev, 0x1e, input_r + 104);  // Adjusting volume offset
        }

        if (output_l > 0) {
            printf("Setting output left volume: %d\n", output_l);
            send(hiddev, 0x07, output_l + 110);  // Adjusting volume offset
        }

        if (output_r > 0) {
            printf("Setting output right volume: %d\n", output_r);
            send(hiddev, 0x09, output_r + 110);  // Adjusting volume offset
        }

        hid_close(hiddev);  // Close the device
    } else {
        printf("Unable to open the HID device\n");
        return -1;
    }

    hid_exit();  // Exit HID library
    return 0;
}
