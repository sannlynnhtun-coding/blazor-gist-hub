# GistHub မှာ Style နဲ့ Theme ကို ဘယ်လို ခွဲသုံးထားလဲ

Theme အများကြီး ထည့်ထားလို့
UI က အလိုလို ကြည့်ကောင်းသွားတာတော့ မဟုတ်ဘူးဗျ။

အရောင်လှတာလည်း လိုတယ်။
ဒါပေမယ့် စာဖတ်ရလား၊ Button ကို ရှာတွေ့လား၊
ဘယ်ဟာကို ရွေးထားလဲ သိသာရလားဆိုတာပါ စစ်ဖို့လိုတယ်။

GistHub မှာတော့ Style၊ Theme နဲ့ Color Placement ကို ခွဲထားပါတယ်။

## Style က ပုံစံ၊ Theme က အရောင်

Style က Card ရဲ့ ထောင့်၊ Border၊ Shadow၊
Heading နဲ့ Background ပုံစံကို ပြောင်းပေးတယ်။

Theme က နောက်ခံ၊ စာသား၊ Button နဲ့
Code Syntax အရောင်တွေကို သတ်မှတ်ပေးတယ်။

ဥပမာ `Cruip + Tokyo Night` ဆိုရင်
Cruip ရဲ့ ရှင်းလင်းတဲ့ Dashboard ပုံစံကို
Tokyo Night ရဲ့ အရောင်တွေနဲ့ တွဲသုံးတာပါ။

အဲ့ဒီကနေ Flat ကို ပြောင်းလိုက်ရင်
အရောင်ကို ဆက်ထားပြီး Card နဲ့ Control ပုံစံတွေ ပြောင်းမယ်။
Style နဲ့ Theme နှစ်ခုလုံး တစ်ခါတည်း ပြောင်းချင်ရင်တော့ Preset ကို ရွေးလို့ရပါတယ်။

မူလ Default Style နဲ့ Light/Dark ကိုလည်း ဆက်ထားပါတယ်။

## အရောင်အသစ်ထည့်တာထက် နေရာချထားပုံကို ပြန်စစ်တယ်

Card တိုင်း၊ Sidebar တိုင်း၊ Dialog တိုင်းကို
Accent Color အပြည့် ဖြည့်ထားရင်
ဘယ်ဟာက အရေးကြီးလဲ ခွဲရခက်သွားနိုင်တယ်။

အဲ့တာကြောင့် Content ဖတ်ရတဲ့ Surface တွေကို တည်ငြိမ်အောင်ထားပြီး
Primary Action၊ Selected State၊ Link နဲ့ Focus မှာ
Accent ကို အဓိက သုံးထားပါတယ်။

Button နောက်ခံအရောင် လှတယ်ဆိုတာနဲ့ မပြီးသေးဘူး။
အဲ့ဒီအပေါ်က စာကို ဖတ်လို့ရလားဆိုတာပါ စစ်တယ်။

လက်ရှိ Palette Mapping မှာ
Source Theme ထဲက အရောင်တွေကိုပဲ Role ပြန်ခွဲပေးပါတယ်။
စာသားအရောင် မဖတ်ရရင် အဲ့ဒီ Palette ထဲကပဲ
ပိုဖတ်ရလွယ်တဲ့ အရောင်ကို ပြန်ရွေးတယ်။

ဒါက Color Wheel ကနေ အရောင်အသစ်တွေ ထုတ်ပေးတာ မဟုတ်ပါဘူး။
ရှိပြီးသား အရောင်တွေကို နေရာမှန်မှာ ပြန်သုံးတာပါ။

တစ်ခုတော့ ခွဲသိထားဖို့လိုတယ်။
Glass၊ Glow နဲ့ Shadow တွေမှာ Transparency ပါလို့
Screen ပေါ်မှာ မြင်ရတဲ့အရောင်က နောက်ခံနဲ့ ရောသွားနိုင်ပါတယ်။
Palette ထဲက Hex Color ကို မပြောင်းထားပေမယ့်
တကယ်မြင်ရတဲ့ Result ကိုတော့ ပြန်စစ်ဖို့ လိုသေးတယ်။

## ကြည့်ကောင်းမကောင်းကို ခံစားချက်တစ်ခုတည်းနဲ့ မဆုံးဖြတ်ဘူး

လက်ရှိ Automated Test မှာ
Body Text၊ Card Text၊ Button Label နဲ့ Link လို
သတ်မှတ်ထားတဲ့ Color Pair တွေကို Contrast စစ်ထားပါတယ်။

ပုံမှန်စာသားအတွက် `4.5:1`၊
Focus Color နဲ့ Page Background အတွက် `3:1` ကို Target ထားတယ်။
ဒီ Target တွေက [WCAG Text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) နဲ့
[Non-text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) guidance ကို ကိုးကားထားတာပါ။

ဒါပေမယ့် Test အောင်တာနဲ့
App တစ်ခုလုံး Accessibility ပြည့်စုံသွားပြီလို့ မဆိုလိုပါဘူး။

Code Comment အရောင်၊ Glass နောက်ခံ၊ Hover State နဲ့
Style က ထပ်ဖြည့်ထားတဲ့ Border အားလုံးကို
အဲ့ဒီ Test တစ်ခုတည်းက မစစ်ပေးနိုင်ဘူး။

Code Preview ကတော့ File Language အလိုက် Highlight လုပ်ပြီး
Theme ရဲ့ Syntax Color ကို သုံးထားတယ်။
Copy လုပ်တဲ့အခါ မူရင်း Code ကိုပဲ ရပါတယ်။

## Reference Website တွေကို ဘယ်လို သုံးထားလဲ

[Jesse Showalter ရဲ့ Color Theory ဆောင်းပါး](https://medium.com/@iamjesseshow/creative-basics-color-theory-5a39c6870af3) က
Contrast၊ အရောင်တွေရဲ့ ဆက်စပ်မှုနဲ့ Vibrancy ကို နားလည်ဖို့ Reference ယူထားပါတယ်။
GistHub ရဲ့ Color Mapping Code ကတော့ App အတွက် သီးသန့်ရေးထားတာပါ။

[DesignerUp ရဲ့ UI Design Styles ဆောင်းပါး](https://designerup.co/blog/here-are-6-5-of-the-most-popular-ui-design-trends-and-how-to-design-them/) က
မူလ Style ရွေးစရာ ၇ မျိုးအတွက် Reference ယူထားတယ်။
Screenshot တွေကို အတိအကျ ကူးထားတာထက်
App မှာ အသုံးဝင်မယ့် Border၊ Shadow နဲ့ Surface ပုံစံတွေကို ပြန်ညှိထားပါတယ်။

[Tubik ရဲ့ Color Theory ဆောင်းပါး](https://tubikstudio.com/blog/color-theory-brief-guide-for-designers/) ကတော့
ဖတ်ဖို့ကြိုးစားတဲ့အချိန်မှာ `403` ဖြစ်နေတယ်။
ဒါကြောင့် ဆောင်းပါးအပြည့်ဖတ်ပြီး အားလုံးကို အသုံးချထားတယ်လို့ မပြောနိုင်ပါဘူး။

အရောင် Palette တွေကတော့ [VS Code Themes](https://vscodethemes.com/) က လာတာပါ။
နောက်ထပ် Style တွေအတွက် [UX Planet](https://uxplanet.org/50-design-styles-every-designer-should-know-for-better-prompting-56c09d55db62) ကို Reference ယူထားပြီး
Cruip Style နဲ့ Searchable Popup အတွက် [Artifact](https://cruip.com/demos/artifact/) ကို ကြည့်ထားပါတယ်။

Reference ယူတာနဲ့ Website တစ်ခုလုံးကို ကူးသုံးတာက မတူဘူး။
ဘာကြောင့် အဲ့ဒီ Design က အလုပ်ဖြစ်လဲ နားလည်ပြီး
ကိုယ့် App ရဲ့ Content နဲ့ ပြန်ညှိဖို့ လိုပါတယ်။

## Perfect ဖြစ်ပြီလားဆိုရင်

လက်ရှိ Style ၅၅ မျိုးနဲ့ Default၊
Theme ၁၀၀ နဲ့ Light/Dark ကို တွဲရွေးလို့ရတယ်။
Combination အနေနဲ့ဆို `5,712` ခု ရှိပါတယ်။

အဲ့ဒီ Combination အားလုံးကို
Device တိုင်း၊ Page တိုင်း၊ State တိုင်းမှာ
စစ်ပြီးသားတော့ မဟုတ်ပါဘူး။

Palette Contrast Test၊ Saved Preference Test နဲ့
Desktop/Mobile Browser Check တွေ လုပ်ထားပါတယ်။
ဒါပေမယ့် Physical Device၊ Browser အမျိုးမျိုး၊ Screen Reader နဲ့
တကယ်သုံးတဲ့သူတွေရဲ့ Feedback ကိုလည်း ဆက်စစ်ဖို့ လိုသေးတယ်။

ကိုယ်ရွေးထားတဲ့ Style နဲ့ Theme ကို စမ်းမယ်ဆိုရင်
Card ထဲက စာကို အရင်ဖတ်ကြည့်ပါ။
Button ပေါ်ကို Hover လုပ်ကြည့်ပါ။ Keyboard နဲ့ ရွှေ့ကြည့်ပါ။
Dialog ဖွင့်ကြည့်ပါ။ Mobile မှာ ပြန်ကြည့်ပါ။

အရောင်လှရဲ့လားဆိုတာအပြင်
ဖတ်ရလား၊ နှိပ်ရလွယ်လား၊ ရွေးထားတာ သိသာလားဆိုတာပါ စစ်ကြည့်ပါဗျ။

---

## အဆုံးမှာ ဟာသလေးထည့်ချင်ရင် (optional):

Theme ရွေးတာနဲ့ တစ်နာရီကုန်သွားပြီး
ရေးမယ့် Code ကတော့ `TODO` မှာပဲ ရှိသေးရင်
အဲ့ဒီအပိုင်းကို Color Theory နဲ့တော့ ဖြေရှင်းပေးလို့ မရဘူးပေါ့ဗျာ။
