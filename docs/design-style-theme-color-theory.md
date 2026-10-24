# GistHub: Design Style၊ Theme နဲ့ Color Theory

ရေးသားသည့်နေ့ — 2026-10-24

ဒီ document က လက်ရှိ GistHub implementation ကို အခြေခံပြီး ဘယ်လို design ဆုံးဖြတ်ထားသလဲ၊ reference website တွေကို ဘယ်အတိုင်းအတာအထိ အသုံးပြုထားသလဲ၊ ဘာတွေ စစ်ဆေးပြီးပြီလဲဆိုတာ ရှင်းပြထားပါတယ်။

## 1. ပေးထားတဲ့ website တွေကို အသုံးပြုထားသလား?

**အချို့ကို design အယူအဆနဲ့ style reference အဖြစ် အသုံးပြုထားပါတယ်။ Website သုံးခုလုံးကို တိုက်ရိုက်ကူးထားတာ၊ သူတို့ဆီက palette တွေကို import လုပ်ထားတာတော့ မဟုတ်ပါဘူး။**

| Reference | GistHub မှာ အသုံးပြုပုံ | အတည်ပြုနိုင်တဲ့ အကန့်အသတ် |
|---|---|---|
| [Tubik — Color Theory](https://tubikstudio.com/blog/color-theory-brief-guide-for-designers/) | User ပေးထားတဲ့ color-theory reference | ဖတ်ဖို့ကြိုးစားချိန်မှာ HTTP 403 ဖြစ်နေပါတယ်။ ဆောင်းပါးအပြည့် ဖတ်ပြီး သူ့အချက်အားလုံးကို အသုံးချထားတယ်လို့ မပြောနိုင်ပါဘူး။ |
| [Jesse Showalter — Creative Basics: Color Theory](https://medium.com/@iamjesseshow/creative-basics-color-theory-5a39c6870af3) | အရောင်အချင်းချင်း အလုပ်လုပ်ပုံ၊ contrast နဲ့ vibrancy ကို အသုံးပြုပြီး content နဲ့ action တွေရဲ့ အရေးကြီးမှုကို ခွဲခြားဖို့ reference ယူထားပါတယ်။ | အကြောင်းအရာကို ဖတ်နိုင်ပါတယ်။ App ရဲ့ color-role algorithm ကတော့ GistHub အတွက် သီးသန့်ရေးထားတာပါ။ |
| [DesignerUp — Popular UI Design Styles](https://designerup.co/blog/here-are-6-5-of-the-most-popular-ui-design-trends-and-how-to-design-them/) | မူလရွေးစရာ ၇ မျိုးရဲ့ border၊ shadow၊ geometry နဲ့ surface ပုံစံတွေကို reference ယူထားပါတယ်။ | Style ရဲ့ သဘောသဘာဝကို app အတွက် ပြန်ညှိထားတာဖြစ်ပြီး ဆောင်းပါးရဲ့ screenshots ကို အတိအကျ ပြန်ဆောက်ထားတာ မဟုတ်ပါဘူး။ |

အရောင် palette တွေရဲ့ အဓိက source က **VS Code Themes** ဖြစ်ပါတယ်။ နောက်ထပ် style စာရင်းက [UX Planet ရဲ့ design-style article](https://uxplanet.org/50-design-styles-every-designer-should-know-for-better-prompting-56c09d55db62) ကို reference ယူထားပြီး၊ **Cruip** style နဲ့ searchable popup က [Artifact dashboard](https://cruip.com/demos/artifact/) ရဲ့ interface ကို ကြည့်ပြီး inspiration ယူထားတာပါ။

## 2. Style၊ Theme၊ Preset ကို ဘာလို့ ခွဲထားသလဲ?

| အပိုင်း | တာဝန် | ဥပမာ |
|---|---|---|
| **Visual Style** | ထောင့်၊ border၊ shadow၊ heading typography၊ background texture နဲ့ control ပုံစံ | Cruip၊ Flat၊ Glassmorphism |
| **Color Theme** | နောက်ခံ၊ စာသား၊ accent၊ code syntax အရောင် | Light၊ Dark၊ Tokyo Night |
| **Style + Theme Preset** | Style နဲ့ theme နှစ်ခုလုံးကို တစ်ခါတည်း ရွေးပေးခြင်း | Cyberpunk + Tokyo Night |

ဥပမာ `Cruip + Tokyo Night` ကို ရွေးရင် Cruip ရဲ့ တည်ငြိမ်တဲ့ dashboard ပုံစံနဲ့ Tokyo Night ရဲ့ palette ကို တွဲသုံးပါတယ်။ `Flat` သို့ ပြောင်းရင် ရွေးထားတဲ့ palette ကို ဆက်ထိန်းထားပြီး surface ပုံစံကို ပြောင်းပါတယ်။

လက်ရှိ catalog မှာ **visual style ၅၅ မျိုး + မူလ Default**၊ **VS Code palette ၁၀၀ + မူလ Light/Dark** နဲ့ **preset ၇ ခု** ရှိပါတယ်။ Default appearance ကို မဖယ်ထားပါဘူး။

## 3. ကြည့်လို့ကောင်းအောင် ဘာကို ဦးစားပေးသလဲ?

GistHub မှာ အဓိကလုပ်ရတာ code နဲ့ note ဖတ်ခြင်း၊ ရှာခြင်း၊ သိမ်းခြင်း ဖြစ်ပါတယ်။ ဒါကြောင့် design ဆုံးဖြတ်ချက်တွေမှာ ဒီအစီအစဉ်ကို သုံးထားပါတယ်။

1. **ဖတ်ရလွယ်မှု** — စာသားနဲ့ နောက်ခံ ခွဲမြင်ရမယ်။ Code font နဲ့ wrapping ကို အသုံးဝင်အောင် ထိန်းထားမယ်။
2. **Visual hierarchy** — ဘာက content၊ ဘာက primary action၊ ဘာက အထောက်အကူပြုစာသားလဲဆိုတာ မြင်သာရမယ်။
3. **Consistency** — တူညီတဲ့ control တွေက size နဲ့ interaction တူရမယ်။
4. **Style expression** — အပေါ်က အသုံးပြုရလွယ်မှုတွေကို ထိန်းထားရင်း ကိုယ်နှစ်သက်တဲ့ အသွင်ကို ရွေးနိုင်မယ်။

ဥပမာ sidebar၊ card နဲ့ dialog မျက်နှာပြင်တိုင်းကို accent အရောင်အပြည့် ဖြည့်ရင် action တွေကို ရှာရခက်လာနိုင်ပါတယ်။ ဒါကြောင့် surface တွေကို တည်ငြိမ်အောင် ထားပြီး accent ကို button၊ selected state၊ link နဲ့ focus marker တွေမှာ အဓိက အသုံးပြုထားပါတယ်။

## 4. အရောင်ကို ပြောင်းမဖန်တီးဘဲ နေရာချထားပုံကို ပြောင်းခြင်း

User ရဲ့ “အရောင်မပြောင်းဘဲ color placement ကို ပြောင်းပါ” ဆိုတဲ့ လိုအပ်ချက်အတွက် `mapThemeRoles()` ကို အသုံးပြုထားပါတယ်။

လုပ်ဆောင်ပုံက ဒီလိုပါ။

1. Source theme ထဲက UI colors နဲ့ syntax colors ကို စုပါတယ်။
2. Editor background ကို page background အဖြစ် အခြေခံယူပါတယ်။
3. မူလ foreground က background ပေါ်မှာ ဖတ်ရမလုံလောက်ရင် **အဲဒီ palette ထဲကပဲ** ပိုဖတ်ရလွယ်တဲ့ အရောင်ကို ရွေးပါတယ်။
4. Card နဲ့ muted surface အတွက် နောက်ခံနဲ့ brightness နီးပြီး စာသားဖတ်ရလွယ်တဲ့ source surface တွေကို ရွေးပါတယ်။
5. Primary accent ကို page၊ card နဲ့ muted surface ပေါ်မှာ ခွဲမြင်ရနိုင်တဲ့ source အရောင်တွေထဲက ရွေးပါတယ်။
6. Accent button ပေါ်က label အတွက် accent နဲ့ contrast ကောင်းတဲ့ source အရောင်ကို သီးခြားရွေးပါတယ်။

ဥပမာ palette တစ်ခုထဲမှာ dark background၊ light text နဲ့ vivid accent ရှိရင် page/card ကို dark surface တွေနဲ့ထားပြီး action ကို vivid accent နဲ့ ပြနိုင်ပါတယ်။ Button label ကိုတော့ page ရဲ့ light text အတိုင်း မသတ်မှတ်ဘဲ accent ပေါ်မှာ ဖတ်ရလွယ်မလွယ် စစ်ပြီးမှ ရွေးပါတယ်။

**အတိအကျ ခွဲသိဖို့:** palette role mapping က source palette ပြင်ပက solid color အသစ် မဖန်တီးပါဘူး။ သို့ပေမယ့် style တွေရဲ့ transparent shadow၊ glow၊ gradient နဲ့ glass overlay တွေက မျက်နှာပြင်ပေါ်မှာ အရောင်တွေ ပေါင်းစပ်မြင်ရစေနိုင်ပါတယ်။ ဒါကြောင့် rendered pixel အားလုံးက source hex color အတိုင်းပဲ ဖြစ်မယ်လို့ မဆိုလိုပါဘူး။

ဒီ algorithm က complementary သို့မဟုတ် analogous color wheel ကို အလိုအလျောက် ဖန်တီးပေးတဲ့စနစ်လည်း မဟုတ်ပါဘူး။ ရှိပြီးသား palette ကို UI role တွေဆီ ဖတ်ရလွယ်အောင် ပြန်နေရာချထားတဲ့ စနစ်ပါ။

## 5. Contrast ကို ဘယ်လို စစ်သလဲ?

ရိုးရိုး RGB နံပါတ်ကွာခြားချက်ကိုပဲ မကြည့်ပါဘူး။ sRGB ကို linear luminance ပြောင်းပြီး brightness နဲ့ contrast ratio ကို တွက်ပါတယ်။

```text
contrast ratio = (ပိုလင်းတဲ့အရောင်၏ luminance + 0.05)
                 / (ပိုမှောင်တဲ့အရောင်၏ luminance + 0.05)
```

GistHub ရဲ့ palette test မှာ သတ်မှတ်ထားတဲ့ အဓိက pair တွေက:

| စစ်ဆေးသည့် color pair | လက်ရှိ test ရဲ့ minimum |
|---|---:|
| Body text / page background | 4.5:1 |
| Card text / card surface | 4.5:1 |
| Muted text / muted surface | 4.5:1 |
| Primary button label / primary fill | 4.5:1 |
| Secondary button label / secondary fill | 4.5:1 |
| Link / card surface | 4.5:1 |
| Destructive button label / destructive fill | 4.5:1 |
| Focus color / page background | 3:1 |

ဒါတွေက [WCAG text contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) နဲ့ [non-text contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) ကို ကိုးကားထားတဲ့ target တွေပါ။ လိုအပ်တဲ့ UI state/graphic cues အတွက် 3:1 နဲ့ ပုံမှန်စာသားအတွက် 4.5:1 ဆိုတာ အသုံးပြုထားပါတယ်။

**Test အောင်ခြင်းက app တစ်ခုလုံး WCAG compliant ဖြစ်ပြီလို့ မဆိုလိုပါဘူး။** Test က စာရင်းထဲက token pair တွေကိုပဲ စစ်ပါတယ်။ Style က ထပ်ဖြည့်တဲ့ transparency၊ decorative border၊ overlay၊ hover state အားလုံးကို အပြီးအစီး စစ်ထားတာ မဟုတ်ပါဘူး။

## 6. Style တွေကို app အတွက် ဘယ်လို ပြန်ညှိထားသလဲ?

DesignerUp မှာ ဖော်ပြတဲ့ style သဘောတရားတွေကို လက်ရှိ UI နဲ့ ကိုက်ညီအောင် ပြန်အသုံးပြုထားပါတယ်။

| Style | GistHub မှာ အဓိက ကွာခြားစေတဲ့ treatment |
|---|---|
| Neobrutalism | ပြတ်သားတဲ့ frame နဲ့ offset shadow |
| Bauhaus | Geometric accent နဲ့ တိကျတဲ့ panel ပုံစံ |
| Neumorphism | Raised surface shadow နဲ့ inset input |
| Retro Futurism | Terminal ဆန်တဲ့ heading နဲ့ arcade frame |
| Cyberpunk | Angular corner နဲ့ ထိန်းထားတဲ့ glow |
| Glassmorphism | Transparent panel၊ blur နဲ့ depth |
| Flat | အလှဆင်နည်းပြီး shadow နည်းတဲ့ surface |
| Cruip | Artifact-inspired rounded card၊ subtle border နဲ့ ရှင်းလင်းတဲ့ controls |

နောက်ထပ် artistic style တွေမှာလည်း အဓိက heading၊ frame၊ corner နဲ့ canvas texture ကို ပြောင်းပါတယ်။ Style name တစ်ခုရဲ့ illustration၊ သမိုင်းဆိုင်ရာ ornament နဲ့ custom font အားလုံးကို ပြန်ထုတ်ပေးတဲ့ full art kit မဟုတ်ပါဘူး။ App မှာ အသုံးပြုနိုင်တဲ့ **UI adaptation** တွေပါ။

Style ရွေးတာကြောင့် code font ကို ornamental font ပြောင်းခြင်း၊ card content ကို လှည့်ခြင်း၊ button အလုပ်လုပ်ပုံကို ပြောင်းခြင်းတွေ မလုပ်ထားပါဘူး။ Preset ကို ရွေးမှသာ style နဲ့ palette နှစ်ခုလုံး ပြောင်းပါတယ်။

## 7. Syntax highlighting က ဘယ်လို ဆက်စပ်သလဲ?

Card preview က file ရဲ့ language metadata ကို ဦးစားပေးပြီး filename extension ကို fallback အဖြစ် သုံးပါတယ်။ ဥပမာ `C#` ကို `csharp`၊ `.tsx` ကို TypeScript highlighter နဲ့ ဆက်စပ်ပေးပါတယ်။ မသိတဲ့ language ကို plain text အဖြစ် ပြပါတယ်။

Highlight.js က keyword၊ string၊ number စတဲ့ token တွေကို HTML class ခွဲပေးပြီး ရွေးထားတဲ့ theme ရဲ့ CSS က အရောင်သတ်မှတ်ပေးပါတယ်။ ဒါကြောင့် theme preview ပြောင်းတဲ့အခါ syntax အရောင်လည်း ချက်ချင်း ပြောင်းနိုင်ပါတယ်။ Copy ကတော့ မူရင်း source text ကိုပဲ ပြန်ပေးပါတယ်။

မူလ Light/Dark က အစကရှိပြီးသား dark code-preview surface နဲ့ bundled syntax palette ကို ဆက်သုံးပါတယ်။ VS Code theme ရွေးထားရင် အဲဒီ theme ရဲ့ code surface နဲ့ syntax colors ကို အသုံးပြုပါတယ်။

Syntax colors တွေကို source preview မှ ဆင်းသက်ယူထားတာပါ။ Language တစ်မျိုးချင်းရဲ့ editor token mapping အားလုံးကို တူညီအောင် ပြန်ထုတ်ထားတာ မဟုတ်သလို comment အရောင်အပါအဝင် token အားလုံး 4.5:1 ပြည့်တယ်ဆိုတာလည်း လက်ရှိ test က အာမမခံပါဘူး။

## 8. Live preview နဲ့ saved preference

- **Themes** — palette သီးခြားရွေးနိုင်ပါတယ်။
- **Styles** — palette ကို ထိန်းပြီး visual treatment ပြောင်းနိုင်ပါတယ်။
- **Presets** — style နဲ့ palette နှစ်ခုလုံး ပြောင်းပါတယ်။
- Hover သို့မဟုတ် keyboard focus က preview ပြပေးပြီး ရွေးချယ်မှုကို မသိမ်းသေးပါဘူး။
- Click သို့မဟုတ် Enter နဲ့ အတည်ပြုမှ localStorage ထဲ သိမ်းပါတယ်။
- Escape၊ popup ပိတ်ခြင်းနဲ့ pointer leave က မသိမ်းထားတဲ့ preview ကို ပြန်ဖျက်ပြီး saved appearance ကို ပြန်ပြပါတယ်။
- Restore default က မူလ style နဲ့ အဲဒီအချိန်က system preference အရ Light/Dark ကို ပြန်ရွေးပေးပါတယ်။

အသုံးပြုထားတဲ့ keys က `theme`၊ `gisthub:theme-choice` နဲ့ `gisthub:interface-style` ပါ။ Browser storage ပိတ်ထားရင် ပြောင်းလဲမှုကို လက်ရှိ page မှာ အသုံးပြုနိုင်ပေမယ့် reload အတွက် သိမ်းထားနိုင်မယ်လို့ မအာမခံနိုင်ပါဘူး။

localStorage က origin အလိုက် သီးခြားဖြစ်လို့ localhost နဲ့ production domain မှာ ရွေးထားတဲ့ preference တူညီနေမယ်လို့ မယူဆသင့်ပါဘူး။ Appearance preference တွေက IndexedDB ထဲက bookmark/gist data နဲ့လည်း သီးခြားပါ။

## 9. “Perfect” ဖြစ်ပြီလား?

**အခြေခံဖတ်ရလွယ်မှုနဲ့ consistency ကို တိုင်းတာစစ်ထားပါတယ်။ လူတိုင်းအတွက် design အားလုံး perfect ဖြစ်ပြီလို့တော့ မပြောနိုင်ပါဘူး။**

လက်ရှိ 56 appearance choices နဲ့ 102 themes ကို အပြန်အလှန် တွဲရင် combination 5,712 ခု ရနိုင်ပါတယ်။ အဲဒီ combination အားလုံးရဲ့ page၊ dialog၊ state၊ language နဲ့ physical device တစ်ခုချင်းကို အပြီးအစီး စစ်ဆေးပြီးသား မဟုတ်ပါဘူး။

စစ်ပြီးသားအရာတွေက:

- Source palette ၁၀၀ ရဲ့ သတ်မှတ်ထားတဲ့ UI color-role pair တွေကို automated contrast test စစ်ထားပါတယ်။
- Style catalog၊ saved preference၊ invalid value fallback နဲ့ blocked storage အခြေအနေတွေကို test စစ်ထားပါတယ်။
- Search၊ keyboard selection၊ live preview၊ cancel၊ reload နဲ့ default restore ကို browser ထဲမှာ စစ်ထားပါတယ်။
- ရှိပြီးသား browser checks တွေမှာ desktop/mobile popup fit၊ card indicator alignment နဲ့ header icon-button size တွေကို စစ်ထားပါတယ်။
- JavaScript၊ C#၊ Python၊ HTML နဲ့ plain-text card preview နမူနာတွေကို browser ထဲမှာ စစ်ထားပါတယ်။

ပိုပြီး အရည်အသွေးမြှင့်ဖို့ ကျန်တဲ့ စစ်ဆေးမှုတွေက physical device၊ browser အမျိုးမျိုး၊ zoom/text scaling၊ screen reader၊ color-vision simulation နဲ့ user feedback ပါ။ Glass သို့မဟုတ် subtle-border style တွေအတွက် rendered background ပေါ်မှာ contrast ပြန်စစ်ဖို့လည်း လိုနိုင်ပါတယ်။ အရောင်တစ်ခုတည်းနဲ့ error သို့မဟုတ် selected state ကို အဓိပ္ပာယ်ဖော်မထားဖို့လည်း စစ်ဆေးသင့်ပါတယ်။ Palette ထဲမှာ ဖတ်ရလွယ်တဲ့ red မရှိရင် destructive role က primary ကို fallback လုပ်နိုင်လို့ label နဲ့ context က အထူးအရေးကြီးပါတယ်။

## 10. Implementation ကို ဘယ်မှာ ကြည့်နိုင်သလဲ?

| File | တာဝန် |
|---|---|
| [theme-color-roles.mjs](../scripts/theme-color-roles.mjs) | Source colors ကို UI role တွေမှာ ပြန်နေရာချခြင်း |
| [test-theme-color-roles.mjs](../scripts/test-theme-color-roles.mjs) | သတ်မှတ်ထားတဲ့ color pair တွေရဲ့ contrast စစ်ခြင်း |
| [theme source notes](../GistHub/ThemeSources/README.md) | Palette source နဲ့ import အကန့်အသတ် |
| [interface-styles.js](../GistHub/wwwroot/js/interface-styles.js) | Style/preset catalog နဲ့ storage |
| [theme.js](../GistHub/wwwroot/js/theme.js) | Theme၊ search၊ preview၊ commit နဲ့ rollback |
| [interface-styles.css](../GistHub/wwwroot/css/interface-styles.css) | မူလ style ရွေးစရာတွေနဲ့ shared style rules |
| [design-styles.css](../GistHub/wwwroot/css/design-styles.css) | Expanded design styles နဲ့ Cruip |
| [vscode-themes.css](../GistHub/wwwroot/css/vscode-themes.css) | Generated page palette နဲ့ syntax token colors |
| [ThemeToggle.razor](../GistHub/Components/UI/ThemeToggle.razor) | Searchable appearance popup |
| [gistPreview.js](../GistHub/wwwroot/js/gistPreview.js) | Card preview syntax highlighting |

ဒီ document ရေးချိန်မှာ အောက်ပါ checks ကို ပြန် run ထားပြီး အောင်မြင်ပါတယ်။

```sh
node scripts/test-theme-color-roles.mjs
node scripts/test-interface-styles.mjs
```

ဒီ task မှာ documentation ကိုပဲ အသစ်ရေးထားပါတယ်။ Runtime design ကို ထပ်မပြင်ထားသလို browser/device စစ်ဆေးမှုအားလုံးကိုလည်း အသစ်ပြန်မလုပ်ထားပါဘူး။
