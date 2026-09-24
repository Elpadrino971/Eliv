import 'dart:async';

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
  Timer? _countdownTimer;

  final formKey = GlobalKey<FormState>();

  void startTimer() {
    _countdownTimer?.cancel();
    if (mounted) setState(() => timer = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (timer <= 1) {
        t.cancel();
      } else {
        setState(() => timer--);
      }
    });
  }

  Future myInitMethod() async {
    startTimer();
    if (widget.fromForget) {
      await authController.forgetPassword(email: widget.email, froResent: true);
    }
  }

  @override
  void initState() {
    super.initState();
    startTimer();
    pins = List.generate(6, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: goldPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: Padding(
        padding: myPadding,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              height(0.04),
              Text(
                'auth_verify_email'.tr,
                style: TextStyle(
                  color: ivory,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Text(
                "We've sent a code to ${widget.email}",
                style: TextStyle(
                  color: textMuted,
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
                    autofocus: i == 0,
                    maxLength: i == 0 ? 6 : 1,
                    onChanged: (value) {
                      if (i == 0 && value.length > 1) {
                        handlePaste(value);
                      } else if (value.length == 1) {
                        if (i == pins.length - 1) {
                          FocusScope.of(context).unfocus();
                        } else {
                          FocusScope.of(context).nextFocus();
                        }
                      } else if (value.isEmpty && i > 0) {
                        // Retour arrière : on remonte à la case précédente,
                        // sinon l'utilisateur reste bloqué sur une case vide.
                        FocusScope.of(context).previousFocus();
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
                        'auth_resend_code_in'.tr,
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
                  // widget.email est TOUJOURS renseigné ; userModel pouvait
                  // être vide et on envoyait alors une adresse vide au serveur,
                  // qui répondait « aucun compte pour cet e-mail ».
                  await authController.forgetPassword(
                    email: widget.email,
                    froResent: true,
                  );
                  startTimer();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icon1.png'),
                    width(0.01),

                    Text(
                      'auth_resend_code'.tr,
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
                label: 'auth_verify_code'.tr,
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
                imageColor: midnightPrimary,
                labelColor: midnightPrimary,
              ),

              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
