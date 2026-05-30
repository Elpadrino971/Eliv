import 'package:artist/Controllers/auth_controller.dart';
import 'package:artist/Global/colors.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/widgets/my_button.dart';
import 'package:artist/widgets/my_pin_input_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OtpScreen extends StatefulWidget {
  final bool fromForget;
  final String email;
  const OtpScreen({super.key, this.fromForget = false, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final authController = Get.find<AuthController>();
  late final List<TextEditingController> pins;
  int timer = 60;

  final formKey = GlobalKey<FormState>();

  Future myTimerMethod() async {
    timer = 60;
    for (int i = 60; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      timer = i;
      setState(() {});
    }
  }

  Future myInitMethod() async {
    myTimerMethod();
    if (widget.fromForget) {
      await authController.forgetPassword(email: widget.email, froResent: true);
    }
  }

  @override
  void initState() {
    super.initState();
    myTimerMethod();
    pins = List.generate(6, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (var i in pins) {
      i.dispose();
    }
    super.dispose();
  }

  // Understand
  void handlePaste(String pasted) {
    final chars = pasted.trim().split('');
    for (var i = 0; i < pins.length; i++) {
      pins[i].text = i < chars.length ? chars[i] : '';
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: myPadding,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              height(0.1),
              Text(
                'Verify Email',
                style: TextStyle(
                  color: blackColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Text(
                "We've sent a code to novinj55@gmail.com",
                style: TextStyle(
                  color: const Color.fromARGB(255, 212, 212, 212),
                  fontWeight: FontWeight.w400,
                ),
              ),

              height(0.02),

              Center(
                child: Image.asset('assets/icon.png', width: 30, height: 30),
              ),

              height(0.02),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) {
                  return MyPinInputField(
                    controller: pins[i],
                    maxLength: i == 0 ? 6 : 1,
                    onChanged: (value) {
                      if (i == 0 && value.length > 1) {
                        handlePaste(value);
                      } else if (value.length == 1) {
                        FocusScope.of(context).nextFocus();
                      }
                    },
                  );
                }),
              ),

              height(0.01),

              timer == 1
                  ? Container()
                  : Center(
                      child: Text(
                        'Resend Code in',
                        style: TextStyle(
                          color: textXolor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
              timer == 1
                  ? Container()
                  : Center(
                      child: Text(
                        '0:$timer',
                        style: TextStyle(
                          color: mainThemeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
              GestureDetector(
                onTap: () async {
                  await authController.forgetPassword(
                    email: userModel.value.user?.email ?? "",
                    froResent: true,
                  );
                  myTimerMethod();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icon1.png'),
                    width(0.01),

                    Text(
                      'Resend Code',
                      style: TextStyle(
                        color: timer == 1 ? blackColor : textXolor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              height(0.02),

              MyButton(
                label: 'Verify Code',
                onTap: () async {
                  if (formKey.currentState!.validate()) {
                    await authController.verifyOtp(
                      email: widget.email,
                      otp: pins.map((e) => e.text).join(),
                      fromForget: widget.fromForget,
                    );
                  }
                },
                image: 'assets/arrow.png',
                imageColor: whiteColor,
                labelColor: whiteColor,
              ),

              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
