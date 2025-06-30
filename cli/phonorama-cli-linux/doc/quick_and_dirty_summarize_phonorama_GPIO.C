typedef struct {
	UCHAR	ucGpioCtrl;
	UCHAR	ucGpioOut;
	UCHAR	ucSpdifTxCtrl_0;
	UCHAR	ucSpdifTxCtrl_1;
	UCHAR	ucSpdifTxCtrl_2;
}USB_GPIO_DATA,PUSB_GPIO_DATA;


void writeGPIO(BYTE data)
{
USB_GPIO_DATA usb_gpio_data;
memset( &usb_gpio_data , 0 , sizeof(usb_gpio_data) );

usb_gpio_data.ucGpioCtrl = 0x7F;
usb_gpio_data.ucGpioOut = data;

 // here I call a function which adds the usb_gpio_data into the belwo array


}

// I write then a data structure of 32 Bytes to the HID interface setting the above usb_gpio_data structure to the below positions int the 32 Byte array.

UCHAR	ucOutReport[32];
ZeroMemory (&(ucOutReport[0]), sizeof (UCHAR) * 32);


ucOutReport[22] = (UCHAR) 0x01;
	// gpio
ucOutReport[23] = gpio_Data->ucGpioCtrl;
ucOutReport[24] = gpio_Data->ucGpioOut;
ucOutReport[25] = gpio_Data->ucSpdifTxCtrl_0;
ucOutReport[26] = gpio_Data->ucSpdifTxCtrl_1;
ucOutReport[27] = gpio_Data->ucSpdifTxCtrl_2;

// Then I send it over HID down to the device.




// Here now the important data:


case 0: // Line in
				bData = 1;
				bGPIO = 0x2;
				break;
			case 1: // MC
				bData = 8;
				bGPIO = 0x45;
				break;
			case 2: // MM
				bData = 8;
				bGPIO = 0x0;
				break;



// now send both data down to the device. One part is the 32 Byte array
// the other is similar to the Maya22 sample 

SetGpio(bGPIO);  // <<---- This must be send with the 32 Byte array see above
SetIICData((0x15<<1), bData);  // <<--- This can be send similar like the Maya22 sample you found in the internet.


