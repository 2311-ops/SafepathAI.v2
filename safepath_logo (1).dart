<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<meta name="design_doc_mode" content="canvas">
<template id="__bundler_thumbnail" data-bg-color="#0C3A3F">
  <svg viewBox="0 0 1200 800" xmlns="http://www.w3.org/2000/svg">
    <rect width="1200" height="800" fill="#0C3A3F"></rect>
    <g transform="translate(600 400)">
      <path d="M0 -150 L150 -97 V40 C150 132 90 192 0 222 C-90 192 -150 132 -150 40 V-97 Z" fill="rgba(255,255,255,0.06)" stroke="#9FE7DF" stroke-width="14" stroke-linejoin="round"></path>
      <path d="M-54 168 C-54 100, 66 86, 42 18 C18 -50, -84 -50, -36 -108" fill="none" stroke="#EAF7F5" stroke-width="22" stroke-linecap="round" stroke-linejoin="round"></path>
      <circle cx="-54" cy="168" r="17" fill="#9FE7DF"></circle>
      <circle cx="-36" cy="-114" r="26" fill="#5FD0C5" stroke="#0C3A3F" stroke-width="9"></circle>
    </g>
  </svg>
</template>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="">
<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&amp;family=JetBrains+Mono:wght@400;500;600&amp;display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@24,400,0,0&amp;display=swap">
<style>
  *{box-sizing:border-box}
  body{margin:0;font-family:'Manrope',sans-serif;-webkit-font-smoothing:antialiased;color:#15302E}
  @keyframes sp_pulse{0%{box-shadow:0 0 0 0 rgba(222,59,64,.5)}70%{box-shadow:0 0 0 26px rgba(222,59,64,0)}100%{box-shadow:0 0 0 0 rgba(222,59,64,0)}}
  @keyframes sp_ping{0%{transform:translate(-50%,-50%) scale(.5);opacity:.6}80%,100%{transform:translate(-50%,-50%) scale(2.4);opacity:0}}
  @keyframes sp_blink{0%,100%{opacity:1}50%{opacity:.3}}
  @keyframes sp_dash{to{stroke-dashoffset:0}}
</style>
</helmet>

<div data-drags-parent="1" style="position:absolute;left:60px;top:-30px;width:1340px;font:800 15px 'JetBrains Mono',monospace;color:#0C3A3F;letter-spacing:.06em">SAFEPATH AI · MOBILE UI/UX — GUARDIAN VIEW · LIGHT MODE</div>

<!-- ===================== DESIGN SYSTEM BOARD ===================== -->
<div style="position:absolute;left:60px;top:20px;width:1340px;background:#FFFFFF;border-radius:24px;box-shadow:0 1px 3px rgba(12,58,63,.1);border:1px solid #E4EAE8;padding:40px 44px">
  <div style="display:flex;justify-content:space-between;align-items:flex-start;border-bottom:1px solid #EEF2F0;padding-bottom:26px;margin-bottom:30px">
    <div>
      <div style="display:flex;align-items:center;gap:14px">
        <div style="width:50px;height:50px;border-radius:14px;background:linear-gradient(150deg,#1A9B8F 0%,#0C3A3F 78%);display:flex;align-items:center;justify-content:center;box-shadow:0 5px 14px rgba(12,58,63,.28)"><svg width="34" height="34" viewBox="0 0 100 100" fill="none"><path d="M50 14 L78 24 V50 C78 68 66 80 50 86 C34 80 22 68 22 50 V24 Z" fill="rgba(255,255,255,.08)" stroke="#9FE7DF" stroke-width="3.4" stroke-linejoin="round"></path><path d="M40 78 C40 66 62 64 58 52 C54 40 36 40 44 31" stroke="#EAF7F5" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"></path><circle cx="40" cy="78" r="4.4" fill="#9FE7DF"></circle><circle cx="44" cy="29" r="6.6" fill="#5FD0C5" stroke="#0C3A3F" stroke-width="2.6"></circle></svg></div>
        <div style="font:800 30px 'Manrope';letter-spacing:-.02em">SafePath AI</div>
      </div>
      <div style="margin-top:10px;color:#5E726F;font-size:15px;max-width:560px;line-height:1.5">Family safety &amp; location intelligence. Calm by default, urgent only when it matters — every signal explained in plain language.</div>
    </div>
    <div style="font:600 12px 'JetBrains Mono',monospace;color:#8A9893;text-align:right;line-height:1.8">DESIGN SYSTEM<br>v1 · 2026</div>
  </div>

  <div style="display:grid;grid-template-columns:1.15fr 1fr;gap:48px">
    <!-- LEFT: palette + type -->
    <div>
      <div style="font:700 12px 'JetBrains Mono',monospace;color:#8A9893;letter-spacing:.08em;margin-bottom:16px">COLOR</div>
      <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px">
        <div><div style="height:64px;border-radius:14px;background:#0C3A3F"></div><div style="font:700 13px 'Manrope';margin-top:8px">Deep Teal</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">#0C3A3F</div></div>
        <div><div style="height:64px;border-radius:14px;background:#15807C"></div><div style="font:700 13px 'Manrope';margin-top:8px">Primary</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">#15807C</div></div>
        <div><div style="height:64px;border-radius:14px;background:#2F9E6B"></div><div style="font:700 13px 'Manrope';margin-top:8px">Safe</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">#2F9E6B</div></div>
        <div><div style="height:64px;border-radius:14px;background:#C98A2B"></div><div style="font:700 13px 'Manrope';margin-top:8px">Caution</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">#C98A2B</div></div>
        <div><div style="height:64px;border-radius:14px;background:#DE3B40;outline:3px solid #FBE0E1;outline-offset:2px"></div><div style="font:700 13px 'Manrope';margin-top:8px">SOS Red</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">#DE3B40</div></div>
        <div><div style="height:64px;border-radius:14px;background:#ECF0EF;border:1px solid #E4EAE8"></div><div style="font:700 13px 'Manrope';margin-top:8px">App BG</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">#ECF0EF</div></div>
        <div><div style="height:64px;border-radius:14px;background:#15302E"></div><div style="font:700 13px 'Manrope';margin-top:8px">Ink</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">#15302E</div></div>
        <div><div style="height:64px;border-radius:14px;background:#FFFFFF;border:1px solid #E4EAE8"></div><div style="font:700 13px 'Manrope';margin-top:8px">Surface</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">#FFFFFF</div></div>
      </div>
      <div style="margin-top:14px;display:flex;gap:8px;align-items:center;background:#FBE9EA;border:1px solid #F3CFD0;border-radius:10px;padding:10px 14px">
        <span style="font-family:'Material Symbols Rounded';font-size:18px;color:#C42A30">lock</span>
        <span style="font-size:12.5px;color:#9B2E33;line-height:1.4"><b>Red is reserved.</b> Only emergency &amp; SOS states use red — routine warnings use Caution amber.</span>
      </div>

      <div style="font:700 12px 'JetBrains Mono',monospace;color:#8A9893;letter-spacing:.08em;margin:30px 0 16px">TYPE — MANROPE</div>
      <div style="display:flex;flex-direction:column;gap:10px">
        <div style="display:flex;align-items:baseline;gap:16px"><span style="font:800 32px 'Manrope';letter-spacing:-.02em">Everyone's safe</span><span style="font:500 11px 'JetBrains Mono';color:#8A9893">Display / 800</span></div>
        <div style="display:flex;align-items:baseline;gap:16px"><span style="font:700 22px 'Manrope';letter-spacing:-.01em">Walk Me Home</span><span style="font:500 11px 'JetBrains Mono';color:#8A9893">Title / 700</span></div>
        <div style="display:flex;align-items:baseline;gap:16px"><span style="font:600 16px 'Manrope'">Maya is at School — arrived 8:42</span><span style="font:500 11px 'JetBrains Mono';color:#8A9893">Body / 600</span></div>
        <div style="display:flex;align-items:baseline;gap:16px"><span style="font:500 13px 'Manrope';color:#5E726F">Last seen 2 minutes ago · 94% battery</span><span style="font:500 11px 'JetBrains Mono';color:#8A9893">Caption / 500</span></div>
        <div style="display:flex;align-items:baseline;gap:16px"><span style="font:600 12px 'JetBrains Mono';color:#15807C;letter-spacing:.04em">GEOFENCE · ENTERED</span><span style="font:500 11px 'JetBrains Mono';color:#8A9893">Mono label</span></div>
      </div>

      <div style="font:700 12px 'JetBrains Mono',monospace;color:#8A9893;letter-spacing:.08em;margin:28px 0 14px">SPACING · 4PT BASE</div>
      <div style="display:flex;align-items:flex-end;gap:14px">
        <div style="text-align:center"><div style="width:4px;height:4px;background:#15807C;margin:0 auto"></div><div style="font:500 10px 'JetBrains Mono';color:#8A9893;margin-top:6px">4</div></div>
        <div style="text-align:center"><div style="width:8px;height:8px;background:#15807C;margin:0 auto"></div><div style="font:500 10px 'JetBrains Mono';color:#8A9893;margin-top:6px">8</div></div>
        <div style="text-align:center"><div style="width:12px;height:12px;background:#15807C;margin:0 auto"></div><div style="font:500 10px 'JetBrains Mono';color:#8A9893;margin-top:6px">12</div></div>
        <div style="text-align:center"><div style="width:16px;height:16px;background:#15807C;margin:0 auto"></div><div style="font:500 10px 'JetBrains Mono';color:#8A9893;margin-top:6px">16</div></div>
        <div style="text-align:center"><div style="width:24px;height:24px;background:#15807C;margin:0 auto"></div><div style="font:500 10px 'JetBrains Mono';color:#8A9893;margin-top:6px">24</div></div>
        <div style="text-align:center"><div style="width:32px;height:32px;background:#15807C;margin:0 auto"></div><div style="font:500 10px 'JetBrains Mono';color:#8A9893;margin-top:6px">32</div></div>
      </div>
    </div>

    <!-- RIGHT: components + SOS -->
    <div>
      <div style="font:700 12px 'JetBrains Mono',monospace;color:#8A9893;letter-spacing:.08em;margin-bottom:16px">COMPONENTS</div>
      <div style="display:flex;gap:10px;flex-wrap:wrap;margin-bottom:18px">
        <div style="background:#15807C;color:#fff;font:700 14px 'Manrope';padding:13px 22px;border-radius:14px">Start walk</div>
        <div style="background:#fff;color:#15807C;font:700 14px 'Manrope';padding:13px 22px;border-radius:14px;border:1.5px solid #BFE0DD">Invite</div>
        <div style="color:#5E726F;font:700 14px 'Manrope';padding:13px 14px;border-radius:14px">Skip</div>
        <div style="background:#15302E;color:#fff;font:700 14px 'Manrope';padding:13px 22px;border-radius:14px;display:flex;align-items:center;gap:8px"><span style="font-family:'Material Symbols Rounded';font-size:18px">person_add</span>Add</div>
      </div>

      <div style="display:flex;flex-direction:column;gap:10px">
        <!-- safe card -->
        <div style="display:flex;align-items:center;gap:13px;background:#EAF5EF;border:1px solid #CDE9DA;border-radius:16px;padding:14px 16px">
          <div style="width:38px;height:38px;border-radius:11px;background:#2F9E6B;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#fff;font-variation-settings:'FILL' 1">check</span></div>
          <div><div style="font:700 14px 'Manrope';color:#1E6E4B">Safe status</div><div style="font:500 12px 'Manrope';color:#4E876C">Calm, reassuring — the default</div></div>
        </div>
        <!-- caution card -->
        <div style="display:flex;align-items:center;gap:13px;background:#FBF3E3;border:1px solid #EFDFBF;border-radius:16px;padding:14px 16px">
          <div style="width:38px;height:38px;border-radius:11px;background:#C98A2B;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#fff">battery_alert</span></div>
          <div><div style="font:700 14px 'Manrope';color:#8A6118">Caution</div><div style="font:500 12px 'Manrope';color:#A57A2E">Low battery · geofence · inactivity</div></div>
        </div>
        <!-- ai explain card -->
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px 16px">
          <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C">auto_awesome</span><div style="font:700 14px 'Manrope'">AI always explains itself</div></div>
          <div style="display:flex;align-items:center;gap:10px"><div style="font:800 26px 'Manrope';color:#2F9E6B">92</div><div style="font:500 12.5px 'Manrope';color:#5E726F;line-height:1.4">Safety score is high — usual route, on-time, battery healthy. <span style="color:#15807C;font-weight:700">Why?</span></div></div>
        </div>
      </div>

      <!-- SOS treatment -->
      <div style="font:700 12px 'JetBrains Mono',monospace;color:#8A9893;letter-spacing:.08em;margin:24px 0 14px">THE SOS BUTTON — SACRED</div>
      <div style="display:flex;align-items:center;gap:24px;background:#0C3A3F;border-radius:18px;padding:22px 24px">
        <div style="position:relative;width:96px;height:96px;flex:none">
          <div style="position:absolute;left:50%;top:50%;width:96px;height:96px;border-radius:50%;background:#DE3B40;transform:translate(-50%,-50%);animation:sp_ping 2.4s ease-out infinite"></div>
          <div style="position:absolute;left:50%;top:50%;width:80px;height:80px;border-radius:50%;background:#DE3B40;transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;justify-content:center;box-shadow:0 10px 24px rgba(222,59,64,.5);border:3px solid rgba(255,255,255,.25)"><span style="font:800 22px 'Manrope';color:#fff;letter-spacing:.04em">SOS</span></div>
        </div>
        <div>
          <div style="color:#fff;font:700 16px 'Manrope';margin-bottom:6px">Press &amp; hold 3 seconds</div>
          <div style="color:#9FC4C1;font:500 13px 'Manrope';line-height:1.5;max-width:230px">Always visible, one tap to reach, impossible to confuse — and hold-to-arm prevents accidental triggers.</div>
        </div>
      </div>
      <div style="margin-top:14px;font:500 12px 'Manrope';color:#8A9893;line-height:1.6"><b style="color:#5E726F">Principles:</b> Calm not alarmist · AI explains itself · Privacy is visible · Accessible by default (44px targets, dynamic type) · One app adapts per role.</div>
    </div>
  </div>
</div>

<!-- ===================== FLOW 1 HEADER ===================== -->
<div data-drags-parent="1" style="position:absolute;left:60px;top:830px;width:1340px;font:800 14px 'JetBrains Mono',monospace;color:#15807C;letter-spacing:.06em">HERO FLOW 01 — ONBOARDING → FAMILY SETUP</div>

<!-- F1-1 WELCOME -->
<div style="position:absolute;left:60px;top:880px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">01 · WELCOME</div>
  <div data-screen-label="Welcome" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:linear-gradient(165deg,#0C3A3F 0%,#0A2D31 55%,#0E4843 100%);display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope';color:#fff"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:0 36px;text-align:center">
        <div style="width:122px;height:122px;border-radius:30px;background:linear-gradient(155deg,#1FA89B 0%,#0C3A3F 75%);display:flex;align-items:center;justify-content:center;margin-bottom:30px;box-shadow:0 18px 40px rgba(8,30,33,.45)"><svg width="84" height="84" viewBox="0 0 100 100" fill="none"><path d="M50 14 L78 24 V50 C78 68 66 80 50 86 C34 80 22 68 22 50 V24 Z" fill="rgba(255,255,255,.08)" stroke="#9FE7DF" stroke-width="3.4" stroke-linejoin="round"></path><path d="M40 78 C40 66 62 64 58 52 C54 40 36 40 44 31" stroke="#EAF7F5" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"></path><circle cx="40" cy="78" r="4.4" fill="#9FE7DF"></circle><circle cx="44" cy="29" r="6.6" fill="#5FD0C5" stroke="#0C3A3F" stroke-width="2.6"></circle></svg></div>
        <div style="font:800 38px 'Manrope';color:#fff;letter-spacing:-.025em;line-height:1.05">SafePath AI</div>
        <div style="font:500 17px 'Manrope';color:#9FC4C1;margin-top:16px;line-height:1.5">Family safety that stays calm —<br>and explains every alert.</div>
      </div>
      <div style="padding:0 28px 44px;display:flex;flex-direction:column;gap:12px">
        <div style="display:flex;align-items:center;justify-content:center;gap:18px;margin-bottom:14px;color:#7FB3AE;font:500 12px 'Manrope'">
          <span style="display:flex;align-items:center;gap:6px"><span style="font-family:'Material Symbols Rounded';font-size:16px">verified_user</span>Private</span>
          <span style="display:flex;align-items:center;gap:6px"><span style="font-family:'Material Symbols Rounded';font-size:16px">bolt</span>Real-time</span>
          <span style="display:flex;align-items:center;gap:6px"><span style="font-family:'Material Symbols Rounded';font-size:16px">psychology</span>Explainable</span>
        </div>
        <div style="background:#5FD0C5;color:#0A2D31;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center">Create your circle</div>
        <div style="color:#CDE7E4;font:600 15px 'Manrope';padding:14px;text-align:center">I already have an account</div>
      </div>
    </div>
  </div>
</div>

<!-- F1-2 REGISTER -->
<div style="position:absolute;left:530px;top:880px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">02 · CREATE ACCOUNT</div>
  <div data-screen-label="Register" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 28px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px;color:#15302E">arrow_back</span></div>
      <div style="flex:1;padding:22px 28px 0;overflow:hidden">
        <div style="font:800 28px 'Manrope';letter-spacing:-.02em">Create account</div>
        <div style="font:500 14px 'Manrope';color:#5E726F;margin-top:8px">Your circle starts with you.</div>
        <div style="margin-top:28px;display:flex;flex-direction:column;gap:16px">
          <div><div style="font:600 12px 'Manrope';color:#5E726F;margin-bottom:7px">FULL NAME</div><div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:15px 16px;display:flex;align-items:center;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#9AAAA6">person</span><span style="font:600 15px 'Manrope'">Maya Rivera</span></div></div>
          <div><div style="font:600 12px 'Manrope';color:#5E726F;margin-bottom:7px">EMAIL</div><div style="background:#fff;border:1.5px solid #15807C;border-radius:14px;padding:15px 16px;display:flex;align-items:center;gap:12px;box-shadow:0 0 0 4px rgba(21,128,124,.1)"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">mail</span><span style="font:600 15px 'Manrope'">maya@rivera.co</span><span style="width:1px;height:20px;background:#15807C;margin-left:-2px;animation:sp_blink 1s steps(1) infinite"></span></div></div>
          <div><div style="font:600 12px 'Manrope';color:#5E726F;margin-bottom:7px">PASSWORD</div><div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:15px 16px;display:flex;align-items:center;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#9AAAA6">lock</span><span style="font:600 16px 'Manrope';letter-spacing:3px;flex:1">••••••••</span><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#9AAAA6">visibility</span></div></div>
        </div>
        <div style="margin-top:18px;display:flex;align-items:flex-start;gap:10px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C;font-variation-settings:'FILL' 1">check_circle</span><span style="font:500 12.5px 'Manrope';color:#5E726F;line-height:1.5">I agree to the Terms &amp; Privacy Policy. SafePath never sells location data.</span></div>
      </div>
      <div style="padding:16px 28px 40px">
        <div style="background:#15807C;color:#fff;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center">Continue</div>
      </div>
    </div>
  </div>
</div>

<!-- F1-3 ROLE SELECT -->
<div style="position:absolute;left:1000px;top:880px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">03 · ROLE SELECTION</div>
  <div data-screen-label="Role selection" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 28px 0;display:flex;align-items:center;gap:6px"><span style="font:600 12px 'JetBrains Mono';color:#9AAAA6">STEP 1 / 3</span><div style="flex:1;height:5px;background:#DDE5E3;border-radius:3px;margin-left:10px;overflow:hidden"><div style="width:33%;height:100%;background:#15807C;border-radius:3px"></div></div></div>
      <div style="flex:1;padding:24px 28px 0">
        <div style="font:800 27px 'Manrope';letter-spacing:-.02em;line-height:1.15">Who are you in<br>this circle?</div>
        <div style="font:500 14px 'Manrope';color:#5E726F;margin-top:10px">You can change this later. It tailors your home screen.</div>
        <div style="margin-top:24px;display:flex;flex-direction:column;gap:12px">
          <div style="background:#fff;border:2px solid #15807C;border-radius:18px;padding:18px;display:flex;align-items:center;gap:14px;box-shadow:0 6px 16px rgba(21,128,124,.12)">
            <div style="width:48px;height:48px;border-radius:14px;background:#E3EFEE;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:26px;color:#15807C">family_restroom</span></div>
            <div style="flex:1"><div style="font:700 16px 'Manrope'">Guardian / Parent</div><div style="font:500 12.5px 'Manrope';color:#5E726F">See the whole circle &amp; manage safety</div></div>
            <span style="font-family:'Material Symbols Rounded';font-size:24px;color:#15807C;font-variation-settings:'FILL' 1">radio_button_checked</span>
          </div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:18px;padding:18px;display:flex;align-items:center;gap:14px">
            <div style="width:48px;height:48px;border-radius:14px;background:#EEF2F0;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:26px;color:#5E726F">school</span></div>
            <div style="flex:1"><div style="font:700 16px 'Manrope'">Member / Teen</div><div style="font:500 12.5px 'Manrope';color:#5E726F">Trusted, not surveilled — full transparency</div></div>
            <span style="font-family:'Material Symbols Rounded';font-size:24px;color:#C5CFCC">radio_button_unchecked</span>
          </div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:18px;padding:18px;display:flex;align-items:center;gap:14px">
            <div style="width:48px;height:48px;border-radius:14px;background:#EEF2F0;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:26px;color:#5E726F">elderly</span></div>
            <div style="flex:1"><div style="font:700 16px 'Manrope'">Elderly care</div><div style="font:500 12.5px 'Manrope';color:#5E726F">Large, simple UI &amp; one-tap help</div></div>
            <span style="font-family:'Material Symbols Rounded';font-size:24px;color:#C5CFCC">radio_button_unchecked</span>
          </div>
        </div>
      </div>
      <div style="padding:16px 28px 40px"><div style="background:#15807C;color:#fff;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center">Continue</div></div>
    </div>
  </div>
</div>

<!-- F1-4 CREATE CIRCLE -->
<div style="position:absolute;left:1470px;top:880px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">04 · CREATE CIRCLE</div>
  <div data-screen-label="Create circle" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 28px 0;display:flex;align-items:center;gap:6px"><span style="font:600 12px 'JetBrains Mono';color:#9AAAA6">STEP 2 / 3</span><div style="flex:1;height:5px;background:#DDE5E3;border-radius:3px;margin-left:10px;overflow:hidden"><div style="width:66%;height:100%;background:#15807C;border-radius:3px"></div></div></div>
      <div style="flex:1;padding:24px 28px 0">
        <div style="font:800 27px 'Manrope';letter-spacing:-.02em">Name your circle</div>
        <div style="font:500 14px 'Manrope';color:#5E726F;margin-top:10px">A private space just for your family.</div>
        <div style="margin-top:28px;display:flex;flex-direction:column;align-items:center">
          <div style="width:84px;height:84px;border-radius:24px;background:#15807C;display:flex;align-items:center;justify-content:center;box-shadow:0 10px 22px rgba(21,128,124,.3)"><span style="font-family:'Material Symbols Rounded';font-size:44px;color:#fff;font-variation-settings:'FILL' 1">diversity_3</span></div>
          <div style="display:flex;gap:10px;margin-top:16px">
            <div style="width:26px;height:26px;border-radius:50%;background:#15807C;border:2px solid #fff;box-shadow:0 0 0 2px #15807C"></div>
            <div style="width:26px;height:26px;border-radius:50%;background:#2F9E6B"></div>
            <div style="width:26px;height:26px;border-radius:50%;background:#C98A2B"></div>
            <div style="width:26px;height:26px;border-radius:50%;background:#6E66C9"></div>
            <div style="width:26px;height:26px;border-radius:50%;background:#C95E8F"></div>
          </div>
        </div>
        <div style="margin-top:26px"><div style="font:600 12px 'Manrope';color:#5E726F;margin-bottom:7px">CIRCLE NAME</div><div style="background:#fff;border:1.5px solid #15807C;border-radius:14px;padding:16px 18px;font:700 18px 'Manrope';box-shadow:0 0 0 4px rgba(21,128,124,.1)">The Rivera Family</div></div>
        <div style="margin-top:18px;display:flex;align-items:center;gap:10px;background:#E3EFEE;border-radius:12px;padding:13px 16px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C">visibility_off</span><span style="font:500 12.5px 'Manrope';color:#1B6A66;line-height:1.4">End-to-end private. Only members you invite can ever join.</span></div>
      </div>
      <div style="padding:16px 28px 40px"><div style="background:#15807C;color:#fff;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center">Create circle</div></div>
    </div>
  </div>
</div>

<!-- F1-5 INVITE -->
<div style="position:absolute;left:1940px;top:880px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">05 · INVITE A MEMBER</div>
  <div data-screen-label="Invite member" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 28px 0;display:flex;align-items:center;justify-content:space-between"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 16px 'Manrope'">Invite</span><span style="font:600 14px 'Manrope';color:#15807C">Done</span></div>
      <div style="flex:1;padding:22px 28px 0">
        <div style="font:800 25px 'Manrope';letter-spacing:-.02em">Add to The Rivera Family</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:20px;padding:22px;margin-top:20px;text-align:center">
          <div style="font:600 12px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em">SCAN OR SHARE CODE</div>
          <div style="width:128px;height:128px;margin:16px auto;border-radius:18px;background:repeating-linear-gradient(45deg,#0C3A3F 0 8px,#fff 8px 16px);position:relative">
            <div style="position:absolute;inset:38px;background:#fff;border-radius:8px;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:30px;color:#15807C;font-variation-settings:'FILL' 1">shield</span></div>
          </div>
          <div style="font:800 24px 'JetBrains Mono';letter-spacing:.18em;color:#0C3A3F">SP-4K9X</div>
          <div style="font:500 12px 'Manrope';color:#8A9893;margin-top:4px">Expires in 24h</div>
        </div>
        <div style="display:flex;gap:10px;margin-top:16px">
          <div style="flex:1;background:#15807C;color:#fff;font:700 14px 'Manrope';padding:14px;border-radius:14px;text-align:center;display:flex;align-items:center;justify-content:center;gap:8px"><span style="font-family:'Material Symbols Rounded';font-size:19px">link</span>Copy link</div>
          <div style="flex:1;background:#fff;color:#15807C;font:700 14px 'Manrope';padding:14px;border-radius:14px;text-align:center;border:1.5px solid #BFE0DD;display:flex;align-items:center;justify-content:center;gap:8px"><span style="font-family:'Material Symbols Rounded';font-size:19px">ios_share</span>Share</div>
        </div>
        <div style="font:700 12px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:24px 0 10px">PENDING</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:13px 15px;display:flex;align-items:center;gap:12px"><div style="width:36px;height:36px;border-radius:50%;background:#FBF3E3;display:flex;align-items:center;justify-content:center;font:700 14px 'Manrope';color:#C98A2B">J</div><div style="flex:1"><div style="font:700 14px 'Manrope'">Jordan (Teen)</div><div style="font:500 12px 'Manrope';color:#8A9893">Invited 2h ago</div></div><span style="font:600 11px 'JetBrains Mono';color:#C98A2B;background:#FBF3E3;padding:5px 10px;border-radius:8px">PENDING</span></div>
      </div>
    </div>
  </div>
</div>

<!-- F1-6 ACCEPT INVITE -->
<div style="position:absolute;left:2410px;top:880px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">06 · ACCEPT / REJECT (RECEIVER)</div>
  <div data-screen-label="Accept invite" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="flex:1;padding:30px 28px 0;display:flex;flex-direction:column;align-items:center;text-align:center">
        <div style="display:flex;align-items:center;justify-content:center;margin-top:14px">
          <div style="width:64px;height:64px;border-radius:50%;background:#15807C;display:flex;align-items:center;justify-content:center;font:800 24px 'Manrope';color:#fff;z-index:2">M</div>
          <div style="width:46px;height:46px;border-radius:50%;background:#0C3A3F;display:flex;align-items:center;justify-content:center;margin-left:-12px"><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#5FD0C5">add</span></div>
        </div>
        <div style="font:800 26px 'Manrope';letter-spacing:-.02em;margin-top:24px;line-height:1.2">Maya invited you to<br>The Rivera Family</div>
        <div style="font:500 14px 'Manrope';color:#5E726F;margin-top:12px;line-height:1.5">Joining lets your circle keep each other safe. Here's exactly what you'll share:</div>
        <div style="width:100%;background:#fff;border:1px solid #E4EAE8;border-radius:18px;padding:6px 18px;margin-top:22px;text-align:left">
          <div style="display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#15807C">location_on</span><div style="flex:1"><div style="font:700 14px 'Manrope'">Live location</div></div><span style="font:600 11px 'Manrope';color:#5E726F">You control when</span></div>
          <div style="display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#15807C">monitor_heart</span><div style="flex:1"><div style="font:700 14px 'Manrope'">Wellness stats</div></div><span style="font:600 11px 'Manrope';color:#C98A2B">Off by default</span></div>
          <div style="display:flex;align-items:center;gap:12px;padding:13px 0"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#15807C">sos</span><div style="flex:1"><div style="font:700 14px 'Manrope'">SOS alerts</div></div><span style="font:600 11px 'Manrope';color:#5E726F">Always two-way</span></div>
        </div>
        <div style="font:500 12px 'Manrope';color:#8A9893;margin-top:14px;display:flex;align-items:center;gap:6px"><span style="font-family:'Material Symbols Rounded';font-size:16px">visibility</span>You'll always see who viewed your location.</div>
      </div>
      <div style="padding:16px 28px 40px;display:flex;flex-direction:column;gap:10px">
        <div style="background:#15807C;color:#fff;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center">Accept &amp; join</div>
        <div style="color:#5E726F;font:600 15px 'Manrope';padding:12px;text-align:center">Decline</div>
      </div>
    </div>
  </div>
</div>

<!-- F1-7 PERMISSIONS -->
<div style="position:absolute;left:2880px;top:880px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">07 · MANAGE PERMISSIONS</div>
  <div data-screen-label="Manage permissions" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 28px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">Permissions</span></div>
      <div style="flex:1;padding:18px 24px 0;overflow:hidden">
        <div style="display:flex;align-items:center;gap:13px;background:#fff;border-radius:18px;padding:16px 18px;border:1px solid #E4EAE8">
          <div style="width:48px;height:48px;border-radius:50%;background:#FBF3E3;display:flex;align-items:center;justify-content:center;font:800 18px 'Manrope';color:#C98A2B">J</div>
          <div style="flex:1"><div style="font:700 16px 'Manrope'">Jordan Rivera</div><div style="font:500 12.5px 'Manrope';color:#5E726F">Member / Teen · 16</div></div>
          <span style="font:600 11px 'JetBrains Mono';color:#1E6E4B;background:#EAF5EF;padding:5px 10px;border-radius:8px">ACTIVE</span>
        </div>
        <div style="font:500 12px 'Manrope';color:#5E726F;margin:18px 4px 10px;line-height:1.5">Jordan can see and change these too — sharing is always mutual and transparent.</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:18px;padding:4px 18px">
          <div style="display:flex;align-items:center;gap:13px;padding:15px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#15807C">location_on</span><div style="flex:1"><div style="font:700 14.5px 'Manrope'">Share live location</div><div style="font:500 11.5px 'Manrope';color:#8A9893">While the app is in use</div></div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="display:flex;align-items:center;gap:13px;padding:15px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#15807C">history</span><div style="flex:1"><div style="font:700 14.5px 'Manrope'">View location history</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Past 7 days</div></div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="display:flex;align-items:center;gap:13px;padding:15px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#15807C">sos</span><div style="flex:1"><div style="font:700 14.5px 'Manrope'">SOS responder</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Gets alerts &amp; live stream</div></div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="display:flex;align-items:center;gap:13px;padding:15px 0"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#9AAAA6">monitor_heart</span><div style="flex:1"><div style="font:700 14.5px 'Manrope'">Share wellness stats</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Steps, activity</div></div><div style="width:46px;height:28px;border-radius:16px;background:#DDE5E3;position:relative"><div style="position:absolute;left:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
        </div>
        <div style="margin-top:18px;display:flex;align-items:center;justify-content:center;gap:8px;color:#C42A30;font:700 14px 'Manrope'"><span style="font-family:'Material Symbols Rounded';font-size:20px">person_remove</span>Remove from circle</div>
      </div>
    </div>
  </div>
</div>

<!-- ===================== FLOW 2 HEADER ===================== -->
<div data-drags-parent="1" style="position: absolute; left: 74px; top: 1842px; width: 1340px; font: 800 14px 'JetBrains Mono',monospace; color: #DE3B40; letter-spacing: .06em">HERO FLOW 02 — SOS TRIGGER → ALERT RESOLUTION  ·  + SILENT / DURESS</div>

<!-- F2-1 HOME / LIVE MAP (interactive SOS) -->
<div style="position:absolute;left:60px;top:1900px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">01 · HOME / LIVE MAP  ·  hold the SOS ↓</div>
  <div data-screen-label="Home / Live Map" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <!-- map fills -->
      <div style="position:absolute;inset:0;background:linear-gradient(160deg,#E8EFEC 0%,#E0EAE7 55%,#DCE9E9 100%);overflow:hidden">
        <div style="position:absolute;left:-50px;bottom:-70px;width:280px;height:250px;background:#CFE3E6;border-radius:50%;opacity:.6"></div>
        <div style="position:absolute;right:-40px;top:120px;width:200px;height:180px;background:#D8E8DB;border-radius:46px;opacity:.75"></div>
        <div style="position:absolute;left:-20px;top:230px;width:130%;height:16px;background:#fff;opacity:.85;transform:rotate(-7deg);border-radius:8px"></div>
        <div style="position:absolute;left:-20px;top:430px;width:130%;height:13px;background:#fff;opacity:.8;transform:rotate(5deg);border-radius:8px"></div>
        <div style="position:absolute;left:150px;top:-20px;width:13px;height:120%;background:#fff;opacity:.8;transform:rotate(6deg);border-radius:8px"></div>
        <div style="position:absolute;left:60px;top:300px;width:70px;height:60px;background:#E6EDEA;border-radius:12px;opacity:.7"></div>
        <div style="position:absolute;right:70px;top:360px;width:80px;height:70px;background:#E6EDEA;border-radius:12px;opacity:.7"></div>
        <!-- pins -->
        <div style="position:absolute;left:175px;top:300px;transform:translate(-50%,-100%);display:flex;flex-direction:column;align-items:center"><div style="position:absolute;left:50%;top:18px;width:48px;height:48px;border-radius:50%;background:rgba(21,128,124,.25);transform:translate(-50%,-50%);animation:sp_ping 2.6s ease-out infinite"></div><div style="width:48px;height:48px;border-radius:50%;background:#15807C;border:3px solid #fff;box-shadow:0 6px 14px rgba(12,58,63,.3);display:flex;align-items:center;justify-content:center;color:#fff;font:800 16px 'Manrope';z-index:2">M</div><div style="width:11px;height:11px;background:#fff;transform:rotate(45deg);margin-top:-6px;box-shadow:0 4px 6px rgba(12,58,63,.18);z-index:1"></div></div>
        <div style="position:absolute;left:95px;top:175px;transform:translate(-50%,-100%);display:flex;flex-direction:column;align-items:center"><div style="width:42px;height:42px;border-radius:50%;background:#C98A2B;border:3px solid #fff;box-shadow:0 6px 14px rgba(12,58,63,.3);display:flex;align-items:center;justify-content:center;color:#fff;font:800 15px 'Manrope'">J</div><div style="width:10px;height:10px;background:#fff;transform:rotate(45deg);margin-top:-6px;box-shadow:0 4px 6px rgba(12,58,63,.18)"></div></div>
        <div style="position:absolute;left:285px;top:415px;transform:translate(-50%,-100%);display:flex;flex-direction:column;align-items:center"><div style="width:42px;height:42px;border-radius:50%;background:#6E66C9;border:3px solid #fff;box-shadow:0 6px 14px rgba(12,58,63,.3);display:flex;align-items:center;justify-content:center;color:#fff;font:800 15px 'Manrope'">G</div><div style="width:10px;height:10px;background:#fff;transform:rotate(45deg);margin-top:-6px;box-shadow:0 4px 6px rgba(12,58,63,.18)"></div></div>
      </div>
      <!-- top chrome over map -->
      <div style="position:relative;z-index:3">
        <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
        <div style="padding:8px 22px 0;display:flex;align-items:center;justify-content:space-between">
          <div><div style="font:500 13px 'Manrope';color:#5E726F">Good morning</div><div style="font:800 21px 'Manrope';letter-spacing:-.02em">The Rivera Family</div></div>
          <div style="display:flex;gap:8px"><div style="width:42px;height:42px;border-radius:14px;background:#fff;box-shadow:0 4px 12px rgba(12,58,63,.1);display:flex;align-items:center;justify-content:center;position:relative"><span style="font-family:'Material Symbols Rounded';font-size:23px;color:#15302E">notifications</span><div style="position:absolute;top:9px;right:10px;width:9px;height:9px;border-radius:50%;background:#DE3B40;border:2px solid #fff"></div></div></div>
        </div>
        <!-- safe banner -->
        <div style="margin:14px 22px 0;background:rgba(234,245,239,.94);backdrop-filter:blur(4px);border:1px solid #CDE9DA;border-radius:16px;padding:13px 16px;display:flex;align-items:center;gap:12px;box-shadow:0 6px 16px rgba(12,58,63,.08)"><div style="width:34px;height:34px;border-radius:10px;background:#2F9E6B;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#fff;font-variation-settings:'FILL' 1">check</span></div><div style="flex:1"><div style="font:700 14px 'Manrope';color:#1E6E4B">Everyone's safe</div><div style="font:500 12px 'Manrope';color:#4E876C">3 in circle · all on usual routine</div></div></div>
      </div>
      <!-- spacer to push member sheet -->
      <div style="flex:1"></div>
      <!-- member chips -->
      <div style="position:relative;z-index:3;padding:0 18px 6px;display:flex;gap:10px;overflow:hidden">
        <div style="background:#fff;border-radius:14px;padding:10px 12px;box-shadow:0 6px 16px rgba(12,58,63,.1);display:flex;align-items:center;gap:9px;min-width:140px"><div style="width:34px;height:34px;border-radius:50%;background:#C98A2B;color:#fff;font:800 13px 'Manrope';display:flex;align-items:center;justify-content:center">J</div><div><div style="font:700 13px 'Manrope'">Jordan</div><div style="font:500 11px 'Manrope';color:#2F9E6B">At School</div></div></div>
        <div style="background:#fff;border-radius:14px;padding:10px 12px;box-shadow:0 6px 16px rgba(12,58,63,.1);display:flex;align-items:center;gap:9px;min-width:140px"><div style="width:34px;height:34px;border-radius:50%;background:#6E66C9;color:#fff;font:800 13px 'Manrope';display:flex;align-items:center;justify-content:center">G</div><div><div style="font:700 13px 'Manrope'">Grandpa</div><div style="font:500 11px 'Manrope';color:#5E726F">Home · 12m</div></div></div>
      </div>
      <!-- bottom nav + SOS -->
      <div style="position:relative;z-index:4;background:#fff;border-top:1px solid #EAEEEC;padding:12px 26px 30px;display:flex;align-items:flex-end;justify-content:space-between;box-shadow:0 -8px 24px rgba(12,58,63,.06)">
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#15807C"><span style="font-family:'Material Symbols Rounded';font-size:25px;font-variation-settings:'FILL' 1">map</span><span style="font:700 10px 'Manrope'">Map</span></div>
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#9AAAA6"><span style="font-family:'Material Symbols Rounded';font-size:25px">timeline</span><span style="font:600 10px 'Manrope'">Activity</span></div>
        <!-- SOS hold button -->
        <div style="position:relative;width:84px;display:flex;flex-direction:column;align-items:center;margin-top:-44px">
          <div onPointerDown="{{ onHoldStart }}" onPointerUp="{{ onHoldEnd }}" onPointerLeave="{{ onHoldEnd }}" onClick="{{ resetSos }}" style="position:relative;width:78px;height:78px;cursor:pointer;user-select:none;touch-action:none">
            <svg width="78" height="78" viewBox="0 0 100 100" style="position:absolute;inset:0;transform:rotate(-90deg)"><circle cx="50" cy="50" r="46" fill="none" stroke="rgba(255,255,255,.0)" stroke-width="0"></circle><circle cx="50" cy="50" r="46" fill="none" stroke="{{ ringColor }}" stroke-width="5" stroke-linecap="round" stroke-dasharray="{{ ringDash }}" stroke-dashoffset="{{ ringOffset }}"></circle></svg>
            <div style="position:absolute;left:50%;top:50%;width:70px;height:70px;border-radius:50%;background:#DE3B40;transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;justify-content:center;box-shadow:0 10px 22px rgba(222,59,64,.45);border:3px solid #fff"><span style="font:800 17px 'Manrope';color:#fff;letter-spacing:.03em">{{ holdLabel }}</span></div>
          </div>
          <span style="font:600 10px 'Manrope';color:#C42A30;margin-top:6px">Hold 3s</span>
        </div>
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#9AAAA6"><span style="font-family:'Material Symbols Rounded';font-size:25px">monitoring</span><span style="font:600 10px 'Manrope'">Insights</span></div>
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#9AAAA6"><span style="font-family:'Material Symbols Rounded';font-size:25px">shield_person</span><span style="font:600 10px 'Manrope'">Privacy</span></div>
      </div>
      <!-- armed toast -->
      <sc-if value="{{ armed }}" hint-placeholder-val="{{ false }}">
        <div style="position:absolute;left:18px;right:18px;bottom:120px;z-index:6;background:#DE3B40;border-radius:16px;padding:14px 18px;display:flex;align-items:center;gap:12px;box-shadow:0 14px 30px rgba(222,59,64,.4);animation:sp_pulse 1.6s infinite"><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#fff">sos</span><div style="flex:1"><div style="font:800 15px 'Manrope';color:#fff">SOS armed — alert sending</div><div style="font:500 12px 'Manrope';color:#FBE0E1">Tap the button to cancel</div></div></div>
      </sc-if>
    </div>
  </div>
</div>

<!-- F2-2 SOS ARMING -->
<div style="position:absolute;left:530px;top:1900px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">02 · ARMING (HOLD TO CONFIRM)</div>
  <div data-screen-label="SOS arming" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:radial-gradient(circle at 50% 42%,#E5484D 0%,#C42A30 55%,#8E1D22 100%);display:flex;flex-direction:column;align-items:center">
      <div style="height:50px;width:100%;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope';color:#fff"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;width:100%;padding:0 32px">
        <div style="font:800 26px 'Manrope';color:#fff;text-align:center;letter-spacing:-.01em">Keep holding to<br>confirm SOS</div>
        <div style="position:relative;width:228px;height:228px;margin:40px 0">
          <svg width="228" height="228" viewBox="0 0 100 100" style="position:absolute;inset:0;transform:rotate(-90deg)"><circle cx="50" cy="50" r="46" fill="none" stroke="rgba(255,255,255,.22)" stroke-width="4"></circle><circle cx="50" cy="50" r="46" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" stroke-dasharray="289" stroke-dashoffset="105"></circle></svg>
          <div style="position:absolute;left:50%;top:50%;width:168px;height:168px;border-radius:50%;background:#fff;transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;justify-content:center;box-shadow:0 12px 30px rgba(0,0,0,.25)"><span style="font:800 40px 'Manrope';color:#C42A30;letter-spacing:.02em">SOS</span><span style="font:700 13px 'Manrope';color:#8E1D22">sending in 1s…</span></div>
        </div>
        <div style="font:600 15px 'Manrope';color:#FBE0E1;text-align:center;line-height:1.5">Release anywhere to cancel.<br>Nothing has been sent yet.</div>
      </div>
      <div style="width:100%;padding:0 28px 46px"><div style="background:rgba(255,255,255,.16);border:1.5px solid rgba(255,255,255,.4);color:#fff;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center;backdrop-filter:blur(4px)">Cancel</div></div>
    </div>
  </div>
</div>

<!-- F2-3 ALERT SENT -->
<div style="position:absolute;left:1000px;top:1900px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">03 · ALERT SENT · LIVE STREAM</div>
  <div data-screen-label="Alert sent" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="background:#DE3B40;padding-bottom:18px">
        <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope';color:#fff"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
        <div style="padding:8px 26px 0;text-align:center">
          <div style="width:56px;height:56px;border-radius:50%;background:rgba(255,255,255,.18);display:flex;align-items:center;justify-content:center;margin:6px auto 0;animation:sp_pulse 1.8s infinite"><span style="font-family:'Material Symbols Rounded';font-size:30px;color:#fff;font-variation-settings:'FILL' 1">sos</span></div>
          <div style="font:800 23px 'Manrope';color:#fff;margin-top:12px">Emergency alert sent</div>
          <div style="display:inline-flex;align-items:center;gap:7px;margin-top:8px;background:rgba(0,0,0,.18);padding:6px 13px;border-radius:20px"><span style="width:9px;height:9px;border-radius:50%;background:#fff;animation:sp_blink 1s infinite"></span><span style="font:700 12px 'Manrope';color:#fff">Streaming your live location</span></div>
        </div>
      </div>
      <div style="flex:1;padding:18px 22px 0;overflow:hidden">
        <div style="font:700 12px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:0 4px 10px">NOTIFYING 3 RESPONDERS</div>
        <div style="background:#fff;border-radius:16px;border:1px solid #E4EAE8;padding:4px 16px">
          <div style="display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #F0F3F2"><div style="width:38px;height:38px;border-radius:50%;background:#15807C;color:#fff;font:800 14px 'Manrope';display:flex;align-items:center;justify-content:center">M</div><div style="flex:1"><div style="font:700 14px 'Manrope'">Maya (Mom)</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Calling now…</div></div><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#2F9E6B;animation:sp_blink 1.2s infinite">call</span></div>
          <div style="display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #F0F3F2"><div style="width:38px;height:38px;border-radius:50%;background:#6E66C9;color:#fff;font:800 14px 'Manrope';display:flex;align-items:center;justify-content:center">D</div><div style="flex:1"><div style="font:700 14px 'Manrope'">Dad</div><div style="font:500 11.5px 'Manrope';color:#2F9E6B">Delivered · seen 8s ago</div></div><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#2F9E6B;font-variation-settings:'FILL' 1">check_circle</span></div>
          <div style="display:flex;align-items:center;gap:12px;padding:13px 0"><div style="width:38px;height:38px;border-radius:50%;background:#15302E;color:#fff;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:20px">local_police</span></div><div style="flex:1"><div style="font:700 14px 'Manrope'">Emergency services</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Ready to call · tap below</div></div></div>
        </div>
        <div style="margin-top:16px;background:#E3EFEE;border-radius:14px;padding:13px 16px;display:flex;align-items:center;gap:11px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C">my_location</span><div style="font:500 12.5px 'Manrope';color:#1B6A66;line-height:1.4"><b>Live location pinned:</b> Elm St &amp; 4th Ave — updating every 3s.</div></div>
      </div>
      <div style="padding:14px 22px 38px;display:flex;flex-direction:column;gap:10px">
        <div style="background:#15302E;color:#fff;font:700 16px 'Manrope';padding:16px;border-radius:16px;text-align:center;display:flex;align-items:center;justify-content:center;gap:9px"><span style="font-family:'Material Symbols Rounded';font-size:21px">call</span>Call 911</div>
        <div style="border:1.5px solid #E4B7B8;color:#C42A30;font:700 15px 'Manrope';padding:14px;border-radius:16px;text-align:center">Hold to cancel alert</div>
      </div>
    </div>
  </div>
</div>

<!-- F2-4 CONTACT STATUS -->
<div style="position:absolute;left:1470px;top:1900px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">04 · RESPONDER STATUS DETAIL</div>
  <div data-screen-label="Responder status" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 24px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">Responder status</span></div>
      <div style="margin:14px 22px 0;background:#FBE9EA;border:1px solid #F3CFD0;border-radius:14px;padding:12px 16px;display:flex;align-items:center;gap:11px"><span style="width:9px;height:9px;border-radius:50%;background:#DE3B40;animation:sp_blink 1s infinite"></span><div style="font:600 12.5px 'Manrope';color:#9B2E33">Alert active · 0:42 elapsed</div></div>
      <div style="flex:1;padding:16px 22px 0;overflow:hidden;display:flex;flex-direction:column;gap:10px">
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:15px 16px;display:flex;align-items:center;gap:13px"><div style="width:42px;height:42px;border-radius:50%;background:#15807C;color:#fff;font:800 15px 'Manrope';display:flex;align-items:center;justify-content:center">M</div><div style="flex:1"><div style="font:700 15px 'Manrope'">Maya (Mom)</div><div style="font:500 12px 'Manrope';color:#5E726F">Push · SMS · Voice call</div></div><div style="text-align:right"><div style="font:700 12px 'Manrope';color:#2F9E6B">On call</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">0:38</div></div></div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:15px 16px;display:flex;align-items:center;gap:13px"><div style="width:42px;height:42px;border-radius:50%;background:#6E66C9;color:#fff;font:800 15px 'Manrope';display:flex;align-items:center;justify-content:center">D</div><div style="flex:1"><div style="font:700 15px 'Manrope'">Dad</div><div style="font:500 12px 'Manrope';color:#5E726F">Push · SMS</div></div><div style="text-align:right"><div style="font:700 12px 'Manrope';color:#2F9E6B">Seen</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">8s ago</div></div></div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:15px 16px;display:flex;align-items:center;gap:13px"><div style="width:42px;height:42px;border-radius:50%;background:#C98A2B;color:#fff;font:800 15px 'Manrope';display:flex;align-items:center;justify-content:center">A</div><div style="flex:1"><div style="font:700 15px 'Manrope'">Aunt Lena</div><div style="font:500 12px 'Manrope';color:#5E726F">Push</div></div><div style="text-align:right"><div style="font:700 12px 'Manrope';color:#C98A2B">Delivered</div><div style="font:500 11px 'JetBrains Mono';color:#8A9893">12s ago</div></div></div>
        <div style="background:#fff;border:1.5px dashed #C5CFCC;border-radius:16px;padding:15px 16px;display:flex;align-items:center;gap:13px;color:#15807C"><span style="font-family:'Material Symbols Rounded';font-size:24px">person_add</span><div style="font:700 14px 'Manrope'">Add a responder</div></div>
      </div>
      <div style="padding:14px 22px 38px"><div style="background:#15302E;color:#fff;font:700 16px 'Manrope';padding:16px;border-radius:16px;text-align:center;display:flex;align-items:center;justify-content:center;gap:9px"><span style="font-family:'Material Symbols Rounded';font-size:21px">forum</span>Message all responders</div></div>
    </div>
  </div>
</div>

<!-- F2-5 DURESS SETUP -->
<div style="position:absolute;left:1940px;top:1900px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">05 · SILENT / DURESS SETUP</div>
  <div data-screen-label="Duress setup" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 24px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">Silent / Duress</span></div>
      <div style="flex:1;padding:18px 24px 0;overflow:hidden">
        <div style="display:flex;align-items:center;gap:12px;background:#0C3A3F;border-radius:18px;padding:18px;color:#fff"><span style="font-family:'Material Symbols Rounded';font-size:30px;color:#5FD0C5">vpn_key</span><div><div style="font:700 16px 'Manrope'">Duress mode</div><div style="font:500 12.5px 'Manrope';color:#9FC4C1;line-height:1.4">A decoy PIN silently sends SOS while the screen looks normal.</div></div></div>
        <div style="font:700 12px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:22px 4px 10px">DECOY PIN</div>
        <div style="display:flex;gap:10px">
          <div style="flex:1;height:56px;border-radius:14px;background:#fff;border:1px solid #E4EAE8;display:flex;align-items:center;justify-content:center;font:800 22px 'Manrope'">0</div>
          <div style="flex:1;height:56px;border-radius:14px;background:#fff;border:1px solid #E4EAE8;display:flex;align-items:center;justify-content:center;font:800 22px 'Manrope'">0</div>
          <div style="flex:1;height:56px;border-radius:14px;background:#fff;border:1.5px solid #15807C;display:flex;align-items:center;justify-content:center;font:800 22px 'Manrope';box-shadow:0 0 0 4px rgba(21,128,124,.1)">0</div>
          <div style="flex:1;height:56px;border-radius:14px;background:#fff;border:1px solid #E4EAE8;display:flex;align-items:center;justify-content:center;color:#C5CFCC;font:800 22px 'Manrope'">_</div>
        </div>
        <div style="font:500 12px 'Manrope';color:#8A9893;margin:8px 4px 0">Different from your real unlock PIN.</div>
        <div style="font:700 12px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:22px 4px 10px">WHEN TRIGGERED</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:4px 16px">
          <div style="display:flex;align-items:center;gap:12px;padding:14px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#15807C">volume_off</span><div style="flex:1"><div style="font:700 14px 'Manrope'">Fully silent</div><div style="font:500 11.5px 'Manrope';color:#8A9893">No sound, no vibration, no banner</div></div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="display:flex;align-items:center;gap:12px;padding:14px 0"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#15807C">wallpaper</span><div style="flex:1"><div style="font:700 14px 'Manrope'">Show decoy screen</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Looks like the weather app</div></div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
        </div>
      </div>
      <div style="padding:14px 24px 38px"><div style="background:#15807C;color:#fff;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center">Enable duress mode</div></div>
    </div>
  </div>
</div>

<!-- F2-6 DECOY SCREEN -->
<div style="position:absolute;left:2410px;top:1900px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#C98A2B;letter-spacing:.04em;margin:0 0 12px 6px">06 · DECOY · SILENTLY STREAMING</div>
  <div data-screen-label="Decoy screen" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:linear-gradient(170deg,#6FA8D6 0%,#8FC0E0 45%,#C7E0EF 100%);display:flex;flex-direction:column;color:#fff">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope';color:#fff"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px;align-items:center"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span><span style="width:6px;height:6px;border-radius:50%;background:#fff;opacity:.55"></span></span></div>
      <div style="flex:1;display:flex;flex-direction:column;align-items:center;padding:40px 30px 0;text-align:center">
        <div style="font:600 18px 'Manrope';opacity:.95">Cedar Falls</div>
        <div style="font:300 92px 'Manrope';line-height:1;margin-top:8px">72°</div>
        <div style="font:600 16px 'Manrope';opacity:.95;margin-top:4px">Partly Cloudy</div>
        <div style="font:500 14px 'Manrope';opacity:.8;margin-top:6px">H:78°  L:61°</div>
        <span style="font-family:'Material Symbols Rounded';font-size:72px;color:#fff;opacity:.95;margin-top:26px;font-variation-settings:'FILL' 1">partly_cloudy_day</span>
        <div style="display:flex;gap:16px;margin-top:36px;background:rgba(255,255,255,.16);border-radius:18px;padding:16px 20px;backdrop-filter:blur(4px)">
          <div style="text-align:center"><div style="font:600 12px 'Manrope';opacity:.85">Now</div><span style="font-family:'Material Symbols Rounded';font-size:26px;margin:8px 0;display:block">sunny</span><div style="font:700 14px 'Manrope'">72°</div></div>
          <div style="text-align:center"><div style="font:600 12px 'Manrope';opacity:.85">1PM</div><span style="font-family:'Material Symbols Rounded';font-size:26px;margin:8px 0;display:block">partly_cloudy_day</span><div style="font:700 14px 'Manrope'">74°</div></div>
          <div style="text-align:center"><div style="font:600 12px 'Manrope';opacity:.85">2PM</div><span style="font-family:'Material Symbols Rounded';font-size:26px;margin:8px 0;display:block">cloud</span><div style="font:700 14px 'Manrope'">73°</div></div>
          <div style="text-align:center"><div style="font:600 12px 'Manrope';opacity:.85">3PM</div><span style="font-family:'Material Symbols Rounded';font-size:26px;margin:8px 0;display:block">rainy</span><div style="font:700 14px 'Manrope'">69°</div></div>
        </div>
      </div>
      <div style="padding:0 0 30px;display:flex;justify-content:center"><div style="width:135px;height:5px;border-radius:3px;background:rgba(255,255,255,.6)"></div></div>
      <!-- annotation (outside the illusion, blueprint note) -->
      <div style="position:absolute;left:14px;right:14px;bottom:54px;background:rgba(12,58,63,.82);border-radius:12px;padding:11px 14px;display:flex;align-items:center;gap:10px;backdrop-filter:blur(2px)"><span style="font-family:'Material Symbols Rounded';font-size:18px;color:#5FD0C5">gps_fixed</span><span style="font:600 11.5px 'JetBrains Mono';color:#CDE7E4;line-height:1.4">DESIGN NOTE: looks benign — SOS &amp; live stream active in background. Tiny dim status dot is the only tell.</span></div>
    </div>
  </div>
</div>

<!-- ===================== FLOW 3 HEADER ===================== -->
<div data-drags-parent="1" style="position:absolute;left:60px;top:2870px;width:1340px;font:800 14px 'JetBrains Mono',monospace;color:#15807C;letter-spacing:.06em">HERO FLOW 03 — WALK-ME-HOME · START → ARRIVAL / ESCALATION</div>

<!-- F3-1 START -->
<div style="position:absolute;left:60px;top:2920px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">01 · PICK DESTINATION &amp; WATCHERS</div>
  <div data-screen-label="Walk-me-home start" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="position:absolute;inset:0 0 360px 0;background:linear-gradient(160deg,#E8EFEC,#DCE9E9);overflow:hidden">
        <div style="position:absolute;left:-30px;top:140px;width:130%;height:14px;background:#fff;opacity:.8;transform:rotate(-6deg);border-radius:8px"></div>
        <div style="position:absolute;left:120px;top:-20px;width:12px;height:120%;background:#fff;opacity:.8;transform:rotate(8deg);border-radius:8px"></div>
        <div style="position:absolute;left:90px;top:120px;transform:translate(-50%,-100%);display:flex;flex-direction:column;align-items:center"><div style="width:44px;height:44px;border-radius:50%;background:#15807C;border:3px solid #fff;box-shadow:0 6px 14px rgba(12,58,63,.3);display:flex;align-items:center;justify-content:center;color:#fff;font:800 15px 'Manrope'">M</div><div style="width:10px;height:10px;background:#fff;transform:rotate(45deg);margin-top:-6px"></div></div>
        <div style="position:absolute;left:255px;top:255px;transform:translate(-50%,-100%);display:flex;flex-direction:column;align-items:center"><div style="width:40px;height:40px;border-radius:12px;background:#2F9E6B;border:3px solid #fff;box-shadow:0 6px 14px rgba(12,58,63,.3);display:flex;align-items:center;justify-content:center;color:#fff"><span style="font-family:'Material Symbols Rounded';font-size:22px;font-variation-settings:'FILL' 1">home</span></div></div>
      </div>
      <div style="position:relative;z-index:2">
        <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
        <div style="padding:8px 22px 0;display:flex;align-items:center;gap:12px"><div style="width:40px;height:40px;border-radius:13px;background:#fff;box-shadow:0 4px 12px rgba(12,58,63,.1);display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:23px">arrow_back</span></div><span style="font:800 20px 'Manrope';letter-spacing:-.02em">Walk Me Home</span></div>
      </div>
      <div style="flex:1"></div>
      <!-- bottom sheet -->
      <div style="position:relative;z-index:2;background:#fff;border-radius:28px 28px 44px 44px;padding:22px 24px 34px;box-shadow:0 -10px 30px rgba(12,58,63,.12)">
        <div style="width:42px;height:5px;border-radius:3px;background:#E0E6E4;margin:0 auto 18px"></div>
        <div style="font:600 12px 'Manrope';color:#5E726F;margin-bottom:8px">DESTINATION</div>
        <div style="background:#F4F6F5;border:1.5px solid #15807C;border-radius:14px;padding:14px 16px;display:flex;align-items:center;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#2F9E6B;font-variation-settings:'FILL' 1">home</span><div style="flex:1"><div style="font:700 15px 'Manrope'">Home</div><div style="font:500 12px 'Manrope';color:#8A9893">12 Oak St · 0.7 mi</div></div><span style="font:700 13px 'Manrope';color:#15807C">8 min</span></div>
        <div style="display:flex;gap:8px;margin-top:12px">
          <div style="background:#E3EFEE;color:#15807C;font:700 13px 'Manrope';padding:9px 15px;border-radius:11px;display:flex;align-items:center;gap:6px"><span style="font-family:'Material Symbols Rounded';font-size:17px">school</span>Dorm</div>
          <div style="background:#F1F4F3;color:#5E726F;font:700 13px 'Manrope';padding:9px 15px;border-radius:11px;display:flex;align-items:center;gap:6px"><span style="font-family:'Material Symbols Rounded';font-size:17px">work</span>Work</div>
          <div style="background:#F1F4F3;color:#5E726F;font:700 13px 'Manrope';padding:9px 15px;border-radius:11px">+ New</div>
        </div>
        <div style="font:600 12px 'Manrope';color:#5E726F;margin:20px 0 10px">WHO'S WATCHING</div>
        <div style="display:flex;align-items:center;gap:10px">
          <div style="display:flex"><div style="width:40px;height:40px;border-radius:50%;background:#15807C;color:#fff;font:800 14px 'Manrope';display:flex;align-items:center;justify-content:center;border:2px solid #fff">M</div><div style="width:40px;height:40px;border-radius:50%;background:#6E66C9;color:#fff;font:800 14px 'Manrope';display:flex;align-items:center;justify-content:center;border:2px solid #fff;margin-left:-10px">D</div></div>
          <div style="width:40px;height:40px;border-radius:50%;background:#F1F4F3;border:1.5px dashed #C5CFCC;display:flex;align-items:center;justify-content:center;color:#15807C"><span style="font-family:'Material Symbols Rounded';font-size:20px">add</span></div>
          <div style="flex:1"></div>
          <div style="font:500 12px 'Manrope';color:#8A9893;text-align:right;max-width:120px;line-height:1.4">They see your route live until you arrive.</div>
        </div>
        <div style="background:#15807C;color:#fff;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center;margin-top:20px;display:flex;align-items:center;justify-content:center;gap:9px"><span style="font-family:'Material Symbols Rounded';font-size:21px">directions_walk</span>Start walk</div>
      </div>
    </div>
  </div>
</div>

<!-- F3-2 IN PROGRESS -->
<div style="position:absolute;left:530px;top:2920px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">02 · IN PROGRESS · LIVE ETA</div>
  <div data-screen-label="Walk in progress" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="position:absolute;inset:0 0 300px 0;background:linear-gradient(160deg,#E8EFEC,#DCE9E9);overflow:hidden">
        <!-- route line -->
        <svg viewBox="0 0 390 540" style="position:absolute;inset:0;width:100%;height:100%"><path d="M90 120 C 140 200, 110 300, 210 360 S 300 430, 300 470" fill="none" stroke="#15807C" stroke-width="7" stroke-linecap="round" stroke-dasharray="2 16" opacity="0.55"></path><path d="M90 120 C 140 200, 110 300, 180 340" fill="none" stroke="#15807C" stroke-width="7" stroke-linecap="round"></path></svg>
        <div style="position:absolute;left:90px;top:120px;transform:translate(-50%,-50%);width:18px;height:18px;border-radius:50%;background:#0C3A3F;border:3px solid #fff;box-shadow:0 4px 10px rgba(0,0,0,.2)"></div>
        <div style="position:absolute;left:300px;top:470px;transform:translate(-50%,-100%);display:flex;flex-direction:column;align-items:center"><div style="width:40px;height:40px;border-radius:12px;background:#2F9E6B;border:3px solid #fff;box-shadow:0 6px 14px rgba(12,58,63,.3);display:flex;align-items:center;justify-content:center;color:#fff"><span style="font-family:'Material Symbols Rounded';font-size:22px;font-variation-settings:'FILL' 1">home</span></div></div>
        <div style="position:absolute;left:180px;top:340px;transform:translate(-50%,-50%)"><div style="position:absolute;left:50%;top:50%;width:40px;height:40px;border-radius:50%;background:rgba(21,128,124,.25);transform:translate(-50%,-50%);animation:sp_ping 2.4s ease-out infinite"></div><div style="width:40px;height:40px;border-radius:50%;background:#15807C;border:3px solid #fff;box-shadow:0 6px 14px rgba(12,58,63,.3);display:flex;align-items:center;justify-content:center;color:#fff;position:relative;z-index:2"><span style="font-family:'Material Symbols Rounded';font-size:22px">directions_walk</span></div></div>
      </div>
      <div style="position:relative;z-index:2">
        <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
        <div style="margin:10px 22px 0;background:rgba(255,255,255,.92);backdrop-filter:blur(4px);border-radius:16px;padding:12px 16px;display:flex;align-items:center;gap:11px;box-shadow:0 6px 16px rgba(12,58,63,.1)"><span style="width:9px;height:9px;border-radius:50%;background:#2F9E6B;animation:sp_blink 1.4s infinite"></span><div style="flex:1"><div style="font:700 13px 'Manrope';color:#1E6E4B">Maya &amp; Dad are watching</div><div style="font:500 11.5px 'Manrope';color:#5E726F">Live route shared · on time</div></div><div style="display:flex"><div style="width:28px;height:28px;border-radius:50%;background:#15807C;color:#fff;font:800 11px 'Manrope';display:flex;align-items:center;justify-content:center;border:2px solid #fff">M</div><div style="width:28px;height:28px;border-radius:50%;background:#6E66C9;color:#fff;font:800 11px 'Manrope';display:flex;align-items:center;justify-content:center;border:2px solid #fff;margin-left:-9px">D</div></div></div>
      </div>
      <div style="flex:1"></div>
      <div style="position:relative;z-index:2;background:#fff;border-radius:28px 28px 44px 44px;padding:24px 24px 34px;box-shadow:0 -10px 30px rgba(12,58,63,.12)">
        <div style="width:42px;height:5px;border-radius:3px;background:#E0E6E4;margin:0 auto 20px"></div>
        <div style="text-align:center"><div style="font:600 13px 'Manrope';color:#5E726F">Arriving home in</div><div style="font:800 52px 'Manrope';letter-spacing:-.03em;color:#0C3A3F;line-height:1.05">8:24</div><div style="font:500 13px 'Manrope';color:#8A9893">ETA 9:49 AM · 0.5 mi to go</div></div>
        <div style="margin-top:18px;height:8px;border-radius:5px;background:#EDF1F0;overflow:hidden"><div style="width:38%;height:100%;background:linear-gradient(90deg,#15807C,#2F9E6B);border-radius:5px"></div></div>
        <div style="display:flex;gap:12px;margin-top:20px">
          <div style="flex:1;background:#fff;border:1.5px solid #E4EAE8;color:#15302E;font:700 15px 'Manrope';padding:15px;border-radius:16px;text-align:center;display:flex;align-items:center;justify-content:center;gap:8px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C">call</span>Call</div>
          <div style="flex:1.4;background:#2F9E6B;color:#fff;font:700 15px 'Manrope';padding:15px;border-radius:16px;text-align:center;display:flex;align-items:center;justify-content:center;gap:8px"><span style="font-family:'Material Symbols Rounded';font-size:20px">check_circle</span>I'm safe</div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- F3-3 ARRIVAL -->
<div style="position:absolute;left:1000px;top:2920px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">03 · ARRIVAL CONFIRMED</div>
  <div data-screen-label="Arrival confirmed" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:linear-gradient(170deg,#2F9E6B 0%,#23875A 60%,#1B6E49 100%);display:flex;flex-direction:column;align-items:center;color:#fff">
      <div style="height:50px;width:100%;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope';color:#fff"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:0 36px;text-align:center">
        <div style="position:relative;width:128px;height:128px;display:flex;align-items:center;justify-content:center"><div style="position:absolute;inset:0;border-radius:50%;background:rgba(255,255,255,.18);animation:sp_pulse 2s infinite"></div><div style="width:104px;height:104px;border-radius:50%;background:#fff;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:64px;color:#23875A;font-variation-settings:'FILL' 1">check</span></div></div>
        <div style="font:800 30px 'Manrope';margin-top:30px;letter-spacing:-.02em">You made it home</div>
        <div style="font:500 15px 'Manrope';color:#D2EFE0;margin-top:10px;line-height:1.5">Arrived 9:46 AM · 7 min walk.<br>Your watchers have been notified.</div>
        <div style="display:flex;gap:10px;margin-top:26px;background:rgba(255,255,255,.14);border-radius:16px;padding:14px 20px;backdrop-filter:blur(4px)">
          <div style="display:flex;align-items:center;gap:8px"><div style="width:30px;height:30px;border-radius:50%;background:#15807C;color:#fff;font:800 12px 'Manrope';display:flex;align-items:center;justify-content:center;border:2px solid #fff">M</div><span style="font:600 13px 'Manrope'">Maya</span><span style="font-family:'Material Symbols Rounded';font-size:18px;color:#D2EFE0">done_all</span></div>
          <div style="width:1px;background:rgba(255,255,255,.3)"></div>
          <div style="display:flex;align-items:center;gap:8px"><div style="width:30px;height:30px;border-radius:50%;background:#6E66C9;color:#fff;font:800 12px 'Manrope';display:flex;align-items:center;justify-content:center;border:2px solid #fff">D</div><span style="font:600 13px 'Manrope'">Dad</span><span style="font-family:'Material Symbols Rounded';font-size:18px;color:#D2EFE0">done_all</span></div>
        </div>
      </div>
      <div style="width:100%;padding:0 28px 46px"><div style="background:#fff;color:#1B6E49;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center">Done</div></div>
    </div>
  </div>
</div>

<!-- F3-4 ESCALATION -->
<div style="position:absolute;left:1470px;top:2920px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#C98A2B;letter-spacing:.04em;margin:0 0 12px 6px">04 · LATE → ESCALATION</div>
  <div data-screen-label="Late escalation" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#FBF3E3;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="flex:1;display:flex;flex-direction:column;align-items:center;padding:24px 30px 0;text-align:center">
        <div style="width:84px;height:84px;border-radius:24px;background:#C98A2B;display:flex;align-items:center;justify-content:center;box-shadow:0 10px 24px rgba(201,138,43,.35)"><span style="font-family:'Material Symbols Rounded';font-size:46px;color:#fff">running_with_errors</span></div>
        <div style="font:800 26px 'Manrope';margin-top:24px;letter-spacing:-.02em;color:#8A6118">Running late?</div>
        <div style="font:500 14.5px 'Manrope';color:#A57A2E;margin-top:10px;line-height:1.55">You haven't arrived home and you've stopped moving near Elm St for 6 minutes.</div>
        <!-- AI explanation -->
        <div style="width:100%;background:#fff;border:1px solid #EFDFBF;border-radius:16px;padding:14px 16px;margin-top:20px;text-align:left;display:flex;gap:11px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C98A2B">auto_awesome</span><div style="font:500 12.5px 'Manrope';color:#8A6118;line-height:1.5"><b>Why we're asking:</b> your ETA passed 4 min ago and you paused off your usual route. Not an emergency yet.</div></div>
        <!-- countdown -->
        <div style="width:100%;background:#fff;border:1px solid #EFDFBF;border-radius:16px;padding:18px;margin-top:12px;display:flex;align-items:center;gap:14px">
          <div style="position:relative;width:64px;height:64px;flex:none"><svg width="64" height="64" viewBox="0 0 100 100" style="transform:rotate(-90deg)"><circle cx="50" cy="50" r="44" fill="none" stroke="#F0E2C4" stroke-width="8"></circle><circle cx="50" cy="50" r="44" fill="none" stroke="#C98A2B" stroke-width="8" stroke-linecap="round" stroke-dasharray="276" stroke-dashoffset="115"></circle></svg><div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font:800 15px 'JetBrains Mono';color:#8A6118">2:00</div></div>
          <div style="text-align:left;flex:1"><div style="font:700 14px 'Manrope';color:#8A6118">Auto-alerting your circle</div><div style="font:500 12px 'Manrope';color:#A57A2E">We'll escalate to SOS unless you check in.</div></div>
        </div>
      </div>
      <div style="padding:14px 28px 40px;display:flex;flex-direction:column;gap:11px">
        <div style="background:#2F9E6B;color:#fff;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center;display:flex;align-items:center;justify-content:center;gap:9px"><span style="font-family:'Material Symbols Rounded';font-size:21px">check_circle</span>I'm OK — extend 15 min</div>
        <div style="background:#DE3B40;color:#fff;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center;display:flex;align-items:center;justify-content:center;gap:9px;box-shadow:0 8px 20px rgba(222,59,64,.3)"><span style="font-family:'Material Symbols Rounded';font-size:21px">sos</span>Send help now</div>
      </div>
    </div>
  </div>
</div>

<!-- ===================== FLOW 4 HEADER ===================== -->
<div data-drags-parent="1" style="position:absolute;left:60px;top:3890px;width:1340px;font:800 14px 'JetBrains Mono',monospace;color:#15807C;letter-spacing:.06em">FEATURE SET 04 — AI INSIGHTS & SAFETY DASHBOARD</div>

<!-- F4-1 SAFETY DASHBOARD -->
<div style="position:absolute;left:60px;top:3940px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">01 · SAFETY SCORE + WHY</div>
  <div data-screen-label="Safety dashboard" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 22px 0;display:flex;align-items:center;justify-content:space-between"><div style="font:800 22px 'Manrope';letter-spacing:-.02em">Safety insights</div><div style="display:flex;align-items:center;gap:6px;background:#E3EFEE;padding:7px 12px;border-radius:20px"><span style="font-family:'Material Symbols Rounded';font-size:17px;color:#15807C">auto_awesome</span><span style="font:700 12px 'Manrope';color:#15807C">AI</span></div></div>
      <div style="flex:1;overflow:hidden;padding:14px 22px 0">
        <!-- score -->
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:20px;padding:20px;display:flex;align-items:center;gap:20px">
          <div style="position:relative;width:96px;height:96px;flex:none"><svg width="96" height="96" viewBox="0 0 100 100"><circle cx="50" cy="50" r="42" fill="none" stroke="#EDF1F0" stroke-width="10"></circle><circle cx="50" cy="50" r="42" fill="none" stroke="#2F9E6B" stroke-width="10" stroke-linecap="round" stroke-dasharray="264" stroke-dashoffset="21" transform="rotate(-90 50 50)"></circle></svg><div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center"><span style="font:800 28px 'Manrope';color:#1E6E4B">92</span><span style="font:600 9px 'JetBrains Mono';color:#8A9893">/ 100</span></div></div>
          <div><div style="font:700 17px 'Manrope';color:#1E6E4B">Calm &amp; safe</div><div style="font:500 13px 'Manrope';color:#5E726F;margin-top:6px;line-height:1.5">Everyone's on their usual routine, on time, with healthy batteries.</div></div>
        </div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:18px 4px 10px">WHY THIS SCORE</div>
        <div style="display:flex;flex-wrap:wrap;gap:8px">
          <div style="background:#EAF5EF;color:#1E6E4B;font:600 12px 'Manrope';padding:8px 12px;border-radius:10px;display:flex;align-items:center;gap:6px"><span style="font-family:'Material Symbols Rounded';font-size:16px">route</span>Usual routes</div>
          <div style="background:#EAF5EF;color:#1E6E4B;font:600 12px 'Manrope';padding:8px 12px;border-radius:10px;display:flex;align-items:center;gap:6px"><span style="font-family:'Material Symbols Rounded';font-size:16px">schedule</span>On schedule</div>
          <div style="background:#EAF5EF;color:#1E6E4B;font:600 12px 'Manrope';padding:8px 12px;border-radius:10px;display:flex;align-items:center;gap:6px"><span style="font-family:'Material Symbols Rounded';font-size:16px">battery_full</span>Batteries OK</div>
        </div>
        <!-- anomaly -->
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:18px 4px 10px">NEEDS A LOOK · 1</div>
        <div style="background:#fff;border:1px solid #EFDFBF;border-radius:16px;padding:14px 16px;display:flex;gap:12px;align-items:flex-start"><div style="width:36px;height:36px;border-radius:11px;background:#FBF3E3;display:flex;align-items:center;justify-content:center;flex:none"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#C98A2B">explore</span></div><div style="flex:1"><div style="font:700 14px 'Manrope';color:#8A6118">Unusual stop · Jordan</div><div style="font:500 12px 'Manrope';color:#5E726F;margin-top:3px;line-height:1.45">Paused 8 min off the usual route home. Low concern.</div></div><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C5CFCC">chevron_right</span></div>
        <!-- ETA -->
        <div style="margin-top:10px;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px 16px;display:flex;gap:12px;align-items:center"><div style="width:36px;height:36px;border-radius:11px;background:#E3EFEE;display:flex;align-items:center;justify-content:center;flex:none"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">timeline</span></div><div style="flex:1"><div style="font:700 14px 'Manrope'">Jordan home by 3:42 PM</div><div style="font:500 12px 'Manrope';color:#5E726F;margin-top:3px">Predicted ±4 min from pace &amp; traffic</div></div></div>
      </div>
      <!-- nav -->
      <div style="background:#fff;border-top:1px solid #EAEEEC;padding:12px 26px 30px;display:flex;align-items:flex-end;justify-content:space-between">
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#9AAAA6"><span style="font-family:'Material Symbols Rounded';font-size:25px">map</span><span style="font:600 10px 'Manrope'">Map</span></div>
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#9AAAA6"><span style="font-family:'Material Symbols Rounded';font-size:25px">timeline</span><span style="font:600 10px 'Manrope'">Activity</span></div>
        <div style="width:64px;height:64px;border-radius:50%;background:#DE3B40;display:flex;flex-direction:column;align-items:center;justify-content:center;margin-top:-40px;border:4px solid #fff;box-shadow:0 8px 18px rgba(222,59,64,.4)"><span style="font:800 15px 'Manrope';color:#fff">SOS</span></div>
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#15807C"><span style="font-family:'Material Symbols Rounded';font-size:25px;font-variation-settings:'FILL' 1">monitoring</span><span style="font:700 10px 'Manrope'">Insights</span></div>
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#9AAAA6"><span style="font-family:'Material Symbols Rounded';font-size:25px">shield_person</span><span style="font:600 10px 'Manrope'">Privacy</span></div>
      </div>
    </div>
  </div>
</div>

<!-- F4-2 ANOMALY DETAIL -->
<div style="position:absolute;left:530px;top:3940px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">02 · ANOMALY · EXPLAINED</div>
  <div data-screen-label="Anomaly detail" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="position:absolute;inset:0 0 480px 0;background:linear-gradient(160deg,#E8EFEC,#DCE9E9);overflow:hidden">
        <svg viewBox="0 0 390 364" style="position:absolute;inset:0;width:100%;height:100%"><path d="M70 300 C 120 260, 110 200, 200 180 S 300 140, 310 90" fill="none" stroke="#C5CFCC" stroke-width="6" stroke-linecap="round" stroke-dasharray="2 14"></path><path d="M70 300 C 130 280, 150 230, 140 180 S 180 120, 250 110" fill="none" stroke="#C98A2B" stroke-width="6" stroke-linecap="round"></path></svg>
        <div style="position:absolute;left:140px;top:180px;transform:translate(-50%,-50%);width:18px;height:18px;border-radius:50%;background:#C98A2B;border:3px solid #fff;box-shadow:0 4px 10px rgba(0,0,0,.2)"></div>
      </div>
      <div style="position:relative;z-index:2;height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="position:relative;z-index:2;padding:8px 22px 0;display:flex;align-items:center;gap:12px"><div style="width:40px;height:40px;border-radius:13px;background:#fff;box-shadow:0 4px 12px rgba(12,58,63,.12);display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:23px">arrow_back</span></div></div>
      <div style="flex:1"></div>
      <div style="position:relative;z-index:2;background:#fff;border-radius:28px 28px 44px 44px;padding:22px 24px 34px;box-shadow:0 -10px 30px rgba(12,58,63,.12)">
        <div style="width:42px;height:5px;border-radius:3px;background:#E0E6E4;margin:0 auto 18px"></div>
        <div style="display:flex;align-items:center;gap:10px"><div style="width:40px;height:40px;border-radius:12px;background:#FBF3E3;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:23px;color:#C98A2B">explore</span></div><div><div style="font:800 19px 'Manrope';letter-spacing:-.01em">Unusual route home</div><div style="font:500 12px 'Manrope';color:#8A9893">Jordan · 3:18 PM · low concern</div></div></div>
        <div style="background:#FBF3E3;border:1px solid #EFDFBF;border-radius:14px;padding:13px 15px;margin-top:16px;display:flex;gap:10px"><span style="font-family:'Material Symbols Rounded';font-size:19px;color:#C98A2B">auto_awesome</span><div style="font:500 12.5px 'Manrope';color:#8A6118;line-height:1.5"><b>Why flagged:</b> Jordan took a path used in only 1 of the last 30 trips and paused 8 min near Elm St — outside the usual 4 routes home.</div></div>
        <div style="display:flex;gap:10px;margin-top:14px">
          <div style="flex:1;background:#F4F6F5;border-radius:12px;padding:12px"><div style="font:600 11px 'Manrope';color:#8A9893">USUAL ETA</div><div style="font:800 17px 'Manrope';margin-top:2px">3:35 PM</div></div>
          <div style="flex:1;background:#F4F6F5;border-radius:12px;padding:12px"><div style="font:600 11px 'Manrope';color:#8A9893">NEW ETA</div><div style="font:800 17px 'Manrope';margin-top:2px;color:#C98A2B">3:51 PM</div></div>
          <div style="flex:1;background:#F4F6F5;border-radius:12px;padding:12px"><div style="font:600 11px 'Manrope';color:#8A9893">BATTERY</div><div style="font:800 17px 'Manrope';margin-top:2px;color:#1E6E4B">76%</div></div>
        </div>
        <div style="display:flex;gap:10px;margin-top:18px">
          <div style="flex:1;background:#fff;border:1.5px solid #E4EAE8;color:#15302E;font:700 14px 'Manrope';padding:14px;border-radius:14px;text-align:center;display:flex;align-items:center;justify-content:center;gap:8px"><span style="font-family:'Material Symbols Rounded';font-size:19px;color:#15807C">chat</span>Message Jordan</div>
          <div style="flex:1;background:#15807C;color:#fff;font:700 14px 'Manrope';padding:14px;border-radius:14px;text-align:center">Looks fine</div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- F4-3 ETA PREDICTION -->
<div style="position:absolute;left:1000px;top:3940px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">03 · ETA PREDICTION</div>
  <div data-screen-label="ETA prediction" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 22px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">Predicted arrival</span></div>
      <div style="flex:1;overflow:hidden;padding:18px 22px 0">
        <div style="background:#0C3A3F;border-radius:20px;padding:22px;color:#fff;text-align:center">
          <div style="display:flex;align-items:center;justify-content:center;gap:8px;font:600 13px 'Manrope';color:#9FC4C1"><span style="font-family:'Material Symbols Rounded';font-size:18px;color:#5FD0C5">auto_awesome</span>Jordan arrives home</div>
          <div style="font:800 46px 'Manrope';letter-spacing:-.02em;margin-top:8px">3:42 PM</div>
          <div style="font:600 13px 'Manrope';color:#5FD0C5">± 4 min · 87% confidence</div>
        </div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:18px 4px 10px">WHAT THE PREDICTION USES</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:4px 16px">
          <div style="display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">directions_walk</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Current pace</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Walking, steady 4.8 km/h</div></div><span style="font:700 12px 'Manrope';color:#1E6E4B">on track</span></div>
          <div style="display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">traffic</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Live conditions</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Light foot traffic on Oak St</div></div><span style="font:700 12px 'Manrope';color:#1E6E4B">clear</span></div>
          <div style="display:flex;align-items:center;gap:12px;padding:13px 0"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">history</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Usual schedule</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Home ~3:40 on weekdays</div></div><span style="font:700 12px 'Manrope';color:#1E6E4B">matches</span></div>
        </div>
        <div style="margin-top:14px;background:#E3EFEE;border-radius:14px;padding:14px 16px;display:flex;align-items:center;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#15807C">notifications_active</span><div style="flex:1;font:600 13px 'Manrope';color:#1B6A66">Notify me when Jordan arrives</div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
      </div>
    </div>
  </div>
</div>

<!-- F4-4 ACTIVITY SUMMARY -->
<div style="position:absolute;left:1470px;top:3940px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">04 · DAILY / WEEKLY SUMMARY</div>
  <div data-screen-label="Activity summary" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 22px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">Jordan · activity</span></div>
      <div style="padding:14px 22px 0"><div style="background:#E4EAE8;border-radius:12px;padding:4px;display:flex"><div style="flex:1;text-align:center;font:700 13px 'Manrope';color:#5E726F;padding:8px">Day</div><div style="flex:1;text-align:center;font:700 13px 'Manrope';color:#15302E;padding:8px;background:#fff;border-radius:9px;box-shadow:0 2px 6px rgba(12,58,63,.1)">Week</div><div style="flex:1;text-align:center;font:700 13px 'Manrope';color:#5E726F;padding:8px">Month</div></div></div>
      <div style="flex:1;overflow:hidden;padding:16px 22px 0">
        <div style="display:flex;gap:10px">
          <div style="flex:1;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px"><div style="font:800 22px 'Manrope'">14</div><div style="font:500 11.5px 'Manrope';color:#8A9893;margin-top:2px">places visited</div></div>
          <div style="flex:1;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px"><div style="font:800 22px 'Manrope'">38<span style="font-size:13px;color:#8A9893"> km</span></div><div style="font:500 11.5px 'Manrope';color:#8A9893;margin-top:2px">distance</div></div>
          <div style="flex:1;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px"><div style="font:800 22px 'Manrope'">31<span style="font-size:13px;color:#8A9893">h</span></div><div style="font:500 11.5px 'Manrope';color:#8A9893;margin-top:2px">time away</div></div>
        </div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:18px;padding:18px;margin-top:14px">
          <div style="font:700 13px 'Manrope';margin-bottom:14px">Time away by day</div>
          <div style="display:flex;align-items:flex-end;justify-content:space-between;height:120px;gap:9px">
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:62%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">M</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:78%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">T</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:55%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">W</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:90%;background:#15807C;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#15807C">T</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:70%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">F</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:35%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">S</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:28%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">S</span></div>
          </div>
        </div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:16px 4px 10px">TOP PLACES</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:4px 16px">
          <div style="display:flex;align-items:center;gap:12px;padding:11px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C">school</span><div style="flex:1;font:600 13.5px 'Manrope'">Lincoln High</div><span style="font:600 12px 'Manrope';color:#8A9893">18h</span></div>
          <div style="display:flex;align-items:center;gap:12px;padding:11px 0"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C">sports_basketball</span><div style="flex:1;font:600 13.5px 'Manrope'">Rec Center</div><span style="font:600 12px 'Manrope';color:#8A9893">5h</span></div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- F4-5 HEATMAP -->
<div style="position:absolute;left:1940px;top:3940px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">05 · LOCATION HEATMAP</div>
  <div data-screen-label="Location heatmap" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="position:absolute;inset:0 0 300px 0;background:linear-gradient(160deg,#E8EFEC,#DCE9E9);overflow:hidden">
        <div style="position:absolute;left:-20px;top:240px;width:130%;height:13px;background:#fff;opacity:.7;transform:rotate(-6deg)"></div>
        <div style="position:absolute;left:150px;top:-20px;width:11px;height:120%;background:#fff;opacity:.7;transform:rotate(6deg)"></div>
        <div style="position:absolute;left:130px;top:200px;width:160px;height:160px;border-radius:50%;background:radial-gradient(circle,rgba(222,59,64,.5),rgba(201,138,43,.35) 45%,transparent 70%)"></div>
        <div style="position:absolute;left:70px;top:330px;width:120px;height:120px;border-radius:50%;background:radial-gradient(circle,rgba(21,128,124,.5),transparent 70%)"></div>
        <div style="position:absolute;left:250px;top:120px;width:110px;height:110px;border-radius:50%;background:radial-gradient(circle,rgba(47,158,107,.45),transparent 70%)"></div>
      </div>
      <div style="position:relative;z-index:2;height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="position:relative;z-index:2;padding:8px 22px 0;display:flex;align-items:center;justify-content:space-between"><div style="display:flex;align-items:center;gap:12px"><div style="width:40px;height:40px;border-radius:13px;background:#fff;box-shadow:0 4px 12px rgba(12,58,63,.12);display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:23px">arrow_back</span></div><span style="font:700 16px 'Manrope';background:#fff;padding:9px 14px;border-radius:12px;box-shadow:0 4px 12px rgba(12,58,63,.1)">Heatmap · 30 days</span></div></div>
      <div style="flex:1"></div>
      <div style="position:relative;z-index:2;background:#fff;border-radius:28px 28px 44px 44px;padding:22px 24px 34px;box-shadow:0 -10px 30px rgba(12,58,63,.12)">
        <div style="width:42px;height:5px;border-radius:3px;background:#E0E6E4;margin:0 auto 16px"></div>
        <div style="display:flex;align-items:center;justify-content:space-between"><div style="font:800 18px 'Manrope'">Where Jordan spends time</div></div>
        <div style="display:flex;align-items:center;gap:8px;margin-top:14px"><span style="font:600 11px 'Manrope';color:#8A9893">Less</span><div style="flex:1;height:9px;border-radius:5px;background:linear-gradient(90deg,#BFE0DD,#2F9E6B,#C98A2B,#DE3B40)"></div><span style="font:600 11px 'Manrope';color:#8A9893">More</span></div>
        <div style="margin-top:16px;display:flex;flex-direction:column;gap:8px">
          <div style="display:flex;align-items:center;gap:12px;background:#F8FAF9;border-radius:12px;padding:12px 14px"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#DE3B40">home</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Home</div><div style="font:500 11px 'Manrope';color:#8A9893">62% of time</div></div><div style="width:90px;height:7px;background:#EDF1F0;border-radius:4px;overflow:hidden"><div style="width:62%;height:100%;background:#DE3B40"></div></div></div>
          <div style="display:flex;align-items:center;gap:12px;background:#F8FAF9;border-radius:12px;padding:12px 14px"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">school</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Lincoln High</div><div style="font:500 11px 'Manrope';color:#8A9893">26% of time</div></div><div style="width:90px;height:7px;background:#EDF1F0;border-radius:4px;overflow:hidden"><div style="width:26%;height:100%;background:#15807C"></div></div></div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- ===================== FLOW 5 HEADER ===================== -->
<div data-drags-parent="1" style="position:absolute;left:60px;top:4910px;width:1340px;font:800 14px 'JetBrains Mono',monospace;color:#15807C;letter-spacing:.06em">FEATURE SET 05 — NOTIFICATIONS, VISIBILITY & PRIVACY (PRIVACY IS VISIBLE)</div>

<!-- F5-1 NOTIFICATIONS CENTER -->
<div style="position:absolute;left:60px;top:4960px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">01 · NOTIFICATIONS CENTER</div>
  <div data-screen-label="Notifications" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 22px 0;display:flex;align-items:center;justify-content:space-between"><div style="font:800 22px 'Manrope';letter-spacing:-.02em">Notifications</div><span style="font:600 13px 'Manrope';color:#15807C">Mark all read</span></div>
      <div style="padding:14px 22px 4px;display:flex;gap:8px;overflow:hidden">
        <div style="background:#15302E;color:#fff;font:700 12px 'Manrope';padding:8px 14px;border-radius:20px">All</div>
        <div style="background:#fff;color:#5E726F;font:700 12px 'Manrope';padding:8px 14px;border-radius:20px;border:1px solid #E4EAE8">SOS</div>
        <div style="background:#fff;color:#5E726F;font:700 12px 'Manrope';padding:8px 14px;border-radius:20px;border:1px solid #E4EAE8">Zones</div>
        <div style="background:#fff;color:#5E726F;font:700 12px 'Manrope';padding:8px 14px;border-radius:20px;border:1px solid #E4EAE8">Battery</div>
      </div>
      <div style="flex:1;overflow:hidden;padding:12px 22px 0">
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:0 4px 10px">TODAY</div>
        <div style="display:flex;flex-direction:column;gap:9px">
          <div style="background:#fff;border:1px solid #F3CFD0;border-left:4px solid #DE3B40;border-radius:14px;padding:13px 15px;display:flex;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#DE3B40">sos</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">SOS resolved · Maya</div><div style="font:500 12px 'Manrope';color:#5E726F;margin-top:2px;line-height:1.4">Alert cancelled after 1m. Everyone marked safe.</div></div><span style="font:500 11px 'JetBrains Mono';color:#8A9893">9:42</span></div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:13px 15px;display:flex;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#2F9E6B">login</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Jordan arrived at School</div><div style="font:500 12px 'Manrope';color:#5E726F;margin-top:2px">Entered the School zone on time.</div></div><span style="font:500 11px 'JetBrains Mono';color:#8A9893">8:42</span></div>
          <div style="background:#fff;border:1px solid #EFDFBF;border-left:4px solid #C98A2B;border-radius:14px;padding:13px 15px;display:flex;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#C98A2B">battery_3_bar</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Grandpa's phone at 18%</div><div style="font:500 12px 'Manrope';color:#5E726F;margin-top:2px">Low battery — a reminder, not an emergency.</div></div><span style="font:500 11px 'JetBrains Mono';color:#8A9893">8:10</span></div>
        </div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:18px 4px 10px">YESTERDAY</div>
        <div style="display:flex;flex-direction:column;gap:9px">
          <div style="background:#fff;border:1px solid #EFDFBF;border-left:4px solid #C98A2B;border-radius:14px;padding:13px 15px;display:flex;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#C98A2B">motion_photos_paused</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Grandpa inactive 3h</div><div style="font:500 12px 'Manrope';color:#5E726F;margin-top:2px">Longer than his usual morning routine.</div></div><span style="font:500 11px 'JetBrains Mono';color:#8A9893">2:15</span></div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:13px 15px;display:flex;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#8A9893">visibility</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Dad viewed your location</div><div style="font:500 12px 'Manrope';color:#5E726F;margin-top:2px">Opened the family map.</div></div><span style="font:500 11px 'JetBrains Mono';color:#8A9893">1:02</span></div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- F5-2 VISIBILITY LEDGER -->
<div style="position:absolute;left:530px;top:4960px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">02 · WHO VIEWED YOU · LEDGER</div>
  <div data-screen-label="Visibility ledger" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 22px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">Who's viewed you</span></div>
      <div style="margin:14px 22px 0;background:#E3EFEE;border-radius:16px;padding:14px 16px;display:flex;gap:11px;align-items:center"><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#15807C">swap_horiz</span><div style="font:500 12.5px 'Manrope';color:#1B6A66;line-height:1.45"><b>Visibility is mutual.</b> Everyone who can see you appears here — and they see the same about you.</div></div>
      <div style="flex:1;overflow:hidden;padding:16px 22px 0">
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:0 4px 10px">TODAY · 4 VIEWS</div>
        <div style="display:flex;flex-direction:column;gap:9px">
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:13px 15px;display:flex;align-items:center;gap:12px"><div style="width:40px;height:40px;border-radius:50%;background:#6E66C9;color:#fff;font:800 14px 'Manrope';display:flex;align-items:center;justify-content:center">D</div><div style="flex:1"><div style="font:700 14px 'Manrope'">Dad</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Opened the family map</div></div><div style="text-align:right"><div style="font:600 11px 'JetBrains Mono';color:#5E726F">1:02 PM</div></div></div>
          <div style="background:#fff;border:1px solid #F3CFD0;border-radius:14px;padding:13px 15px;display:flex;align-items:center;gap:12px"><div style="width:40px;height:40px;border-radius:50%;background:#15807C;color:#fff;font:800 14px 'Manrope';display:flex;align-items:center;justify-content:center">M</div><div style="flex:1"><div style="font:700 14px 'Manrope'">Maya <span style="font:600 10px 'JetBrains Mono';color:#C42A30;background:#FBE9EA;padding:2px 7px;border-radius:6px;margin-left:4px">SOS</span></div><div style="font:500 11.5px 'Manrope';color:#8A9893">During your emergency alert</div></div><div style="text-align:right"><div style="font:600 11px 'JetBrains Mono';color:#5E726F">9:41 AM</div></div></div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:13px 15px;display:flex;align-items:center;gap:12px"><div style="width:40px;height:40px;border-radius:50%;background:#15807C;color:#fff;font:800 14px 'Manrope';display:flex;align-items:center;justify-content:center">M</div><div style="flex:1"><div style="font:700 14px 'Manrope'">Maya</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Checked your walk-home ETA</div></div><div style="text-align:right"><div style="font:600 11px 'JetBrains Mono';color:#5E726F">8:05 AM</div></div></div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:13px 15px;display:flex;align-items:center;gap:12px"><div style="width:40px;height:40px;border-radius:50%;background:#C98A2B;color:#fff;font:800 14px 'Manrope';display:flex;align-items:center;justify-content:center">A</div><div style="flex:1"><div style="font:700 14px 'Manrope'">Aunt Lena</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Opened the family map</div></div><div style="text-align:right"><div style="font:600 11px 'JetBrains Mono';color:#5E726F">7:40 AM</div></div></div>
        </div>
      </div>
      <div style="padding:14px 22px 38px"><div style="border:1.5px solid #BFE0DD;color:#15807C;font:700 15px 'Manrope';padding:15px;border-radius:16px;text-align:center;display:flex;align-items:center;justify-content:center;gap:8px"><span style="font-family:'Material Symbols Rounded';font-size:20px">pause_circle</span>Pause my sharing</div></div>
    </div>
  </div>
</div>

<!-- F5-3 PRIVACY CENTER -->
<div style="position:absolute;left:1000px;top:4960px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">03 · PRIVACY CENTER</div>
  <div data-screen-label="Privacy center" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 22px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">Privacy</span></div>
      <div style="flex:1;overflow:hidden;padding:16px 22px 0">
        <!-- time-boxed -->
        <div style="background:#0C3A3F;border-radius:18px;padding:18px;color:#fff">
          <div style="display:flex;align-items:center;justify-content:space-between"><div style="display:flex;align-items:center;gap:9px"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#5FD0C5">hourglass_top</span><div style="font:700 15px 'Manrope'">Sharing for 1 hour</div></div><div style="width:46px;height:28px;border-radius:16px;background:#5FD0C5;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="font:500 12px 'Manrope';color:#9FC4C1;margin-top:8px">Auto-stops at 10:41 AM — sharing turns off by itself.</div>
          <div style="margin-top:12px;height:6px;background:rgba(255,255,255,.18);border-radius:4px;overflow:hidden"><div style="width:64%;height:100%;background:#5FD0C5;border-radius:4px"></div></div>
        </div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:18px 4px 10px">WHAT YOU SHARE</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:4px 16px">
          <div style="display:flex;align-items:center;gap:12px;padding:14px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">location_on</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Live location</div></div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="display:flex;align-items:center;gap:12px;padding:14px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">history</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Location history</div></div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="display:flex;align-items:center;gap:12px;padding:14px 0"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#9AAAA6">monitor_heart</span><div style="flex:1"><div style="font:700 13.5px 'Manrope'">Wellness &amp; health</div></div><div style="width:46px;height:28px;border-radius:16px;background:#DDE5E3;position:relative"><div style="position:absolute;left:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
        </div>
        <div style="margin-top:12px;background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:14px 16px;display:flex;align-items:center;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">groups</span><div style="flex:1;font:700 13.5px 'Manrope'">Who can see me</div><span style="font:600 12px 'Manrope';color:#8A9893">3 people</span><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C5CFCC">chevron_right</span></div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:18px 4px 10px">YOUR DATA</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:4px 16px">
          <div style="display:flex;align-items:center;gap:12px;padding:14px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">download</span><div style="flex:1;font:700 13.5px 'Manrope'">Export my data</div><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C5CFCC">chevron_right</span></div>
          <div style="display:flex;align-items:center;gap:12px;padding:14px 0"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#DE3B40">delete</span><div style="flex:1;font:700 13.5px 'Manrope';color:#C42A30">Delete my data</div><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#E4B7B8">chevron_right</span></div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- ===================== FLOW 6 HEADER ===================== -->
<div data-drags-parent="1" style="position:absolute;left:60px;top:5980px;width:1340px;font:800 14px 'JetBrains Mono',monospace;color:#15807C;letter-spacing:.06em">FEATURE SET 06 — LOCATION HISTORY & GEOFENCING</div>

<!-- F6-1 HISTORY TIMELINE -->
<div style="position:absolute;left:60px;top:6030px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">01 · HISTORY TIMELINE</div>
  <div data-screen-label="History timeline" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 22px 0;display:flex;align-items:center;justify-content:space-between"><div style="display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">Jordan · history</span></div><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#15807C">map</span></div>
      <div style="padding:12px 22px 0;display:flex;align-items:center;justify-content:center;gap:18px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#9AAAA6">chevron_left</span><span style="font:700 14px 'Manrope'">Today · Thu, Jun 26</span><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#9AAAA6">chevron_right</span></div>
      <div style="flex:1;overflow:hidden;padding:18px 26px 0">
        <div style="position:relative;padding-left:26px">
          <div style="position:absolute;left:7px;top:6px;bottom:10px;width:2px;background:#D5DEDB"></div>
          <div style="position:relative;margin-bottom:22px"><div style="position:absolute;left:-26px;top:2px;width:16px;height:16px;border-radius:50%;background:#2F9E6B;border:3px solid #fff;box-shadow:0 0 0 1px #D5DEDB"></div><div style="font:700 14px 'Manrope'">Home</div><div style="font:500 12px 'Manrope';color:#8A9893">6:40 AM – 7:55 AM · 1h 15m</div></div>
          <div style="position:relative;margin-bottom:22px"><div style="position:absolute;left:-22px;top:4px;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:16px;color:#8A9893">directions_walk</span></div><div style="font:500 12px 'Manrope';color:#8A9893;padding-left:6px">Walked 1.1 km · 14 min</div></div>
          <div style="position:relative;margin-bottom:22px"><div style="position:absolute;left:-26px;top:2px;width:16px;height:16px;border-radius:50%;background:#15807C;border:3px solid #fff;box-shadow:0 0 0 1px #D5DEDB"></div><div style="font:700 14px 'Manrope'">Lincoln High</div><div style="font:500 12px 'Manrope';color:#8A9893">8:09 AM – 3:10 PM · 7h 1m</div></div>
          <div style="position:relative;margin-bottom:22px"><div style="position:absolute;left:-22px;top:4px;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:16px;color:#8A9893">directions_bus</span></div><div style="font:500 12px 'Manrope';color:#8A9893;padding-left:6px">Bus 2.4 km · 11 min</div></div>
          <div style="position:relative;margin-bottom:22px"><div style="position:absolute;left:-26px;top:2px;width:16px;height:16px;border-radius:50%;background:#15807C;border:3px solid #fff;box-shadow:0 0 0 1px #D5DEDB"></div><div style="font:700 14px 'Manrope'">Rec Center</div><div style="font:500 12px 'Manrope';color:#8A9893">3:25 PM – 5:00 PM · 1h 35m</div></div>
          <div style="position:relative"><div style="position:absolute;left:-26px;top:2px;width:16px;height:16px;border-radius:50%;background:#9AAAA6;border:3px solid #fff;box-shadow:0 0 0 1px #D5DEDB"></div><div style="font:700 14px 'Manrope'">Currently walking home</div><div style="font:500 12px 'Manrope';color:#2F9E6B">Live · ETA 5:18 PM</div></div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- F6-2 ROUTE + STATS -->
<div style="position:absolute;left:530px;top:6030px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">02 · ROUTE MAP + TRAVEL STATS</div>
  <div data-screen-label="Route stats" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="position:absolute;inset:0 0 360px 0;background:linear-gradient(160deg,#E8EFEC,#DCE9E9);overflow:hidden">
        <svg viewBox="0 0 390 484" style="position:absolute;inset:0;width:100%;height:100%"><path d="M60 90 C 140 120, 120 220, 220 240 S 320 360, 300 430" fill="none" stroke="#15807C" stroke-width="6" stroke-linecap="round"></path></svg>
        <div style="position:absolute;left:60px;top:90px;transform:translate(-50%,-50%);width:16px;height:16px;border-radius:50%;background:#2F9E6B;border:3px solid #fff;box-shadow:0 4px 8px rgba(0,0,0,.2)"></div>
        <div style="position:absolute;left:300px;top:430px;transform:translate(-50%,-50%);width:18px;height:18px;border-radius:50%;background:#0C3A3F;border:3px solid #fff;box-shadow:0 4px 8px rgba(0,0,0,.2)"></div>
      </div>
      <div style="position:relative;z-index:2;height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="position:relative;z-index:2;padding:8px 22px 0;display:flex;align-items:center;gap:12px"><div style="width:40px;height:40px;border-radius:13px;background:#fff;box-shadow:0 4px 12px rgba(12,58,63,.12);display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:23px">arrow_back</span></div><span style="font:700 16px 'Manrope';background:#fff;padding:9px 14px;border-radius:12px;box-shadow:0 4px 12px rgba(12,58,63,.1)">Today's route</span></div>
      <div style="flex:1"></div>
      <div style="position:relative;z-index:2;background:#fff;border-radius:28px 28px 44px 44px;padding:22px 24px 34px;box-shadow:0 -10px 30px rgba(12,58,63,.12)">
        <div style="width:42px;height:5px;border-radius:3px;background:#E0E6E4;margin:0 auto 18px"></div>
        <div style="display:flex;gap:10px">
          <div style="flex:1;background:#F4F6F5;border-radius:14px;padding:14px;text-align:center"><div style="font:800 21px 'Manrope';color:#0C3A3F">9.2<span style="font-size:12px;color:#8A9893"> km</span></div><div style="font:500 11px 'Manrope';color:#8A9893;margin-top:2px">distance</div></div>
          <div style="flex:1;background:#F4F6F5;border-radius:14px;padding:14px;text-align:center"><div style="font:800 21px 'Manrope';color:#0C3A3F">2h 4m</div><div style="font:500 11px 'Manrope';color:#8A9893;margin-top:2px">in transit</div></div>
          <div style="flex:1;background:#F4F6F5;border-radius:14px;padding:14px;text-align:center"><div style="font:800 21px 'Manrope';color:#0C3A3F">5</div><div style="font:500 11px 'Manrope';color:#8A9893;margin-top:2px">stops</div></div>
        </div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:18px 4px 10px">SEGMENTS</div>
        <div style="display:flex;flex-direction:column;gap:8px">
          <div style="display:flex;align-items:center;gap:12px;background:#F8FAF9;border-radius:12px;padding:11px 14px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C">directions_walk</span><div style="flex:1"><div style="font:700 13px 'Manrope'">Home → School</div><div style="font:500 11px 'Manrope';color:#8A9893">Walk · 1.1 km</div></div><span style="font:600 12px 'Manrope';color:#5E726F">14 min</span></div>
          <div style="display:flex;align-items:center;gap:12px;background:#F8FAF9;border-radius:12px;padding:11px 14px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C">directions_bus</span><div style="flex:1"><div style="font:700 13px 'Manrope'">School → Rec Center</div><div style="font:500 11px 'Manrope';color:#8A9893">Bus · 2.4 km</div></div><span style="font:600 12px 'Manrope';color:#5E726F">11 min</span></div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- F6-3 GEOFENCE MANAGE -->
<div style="position:absolute;left:1000px;top:6030px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">03 · ZONES · CREATE / MANAGE</div>
  <div data-screen-label="Geofence manage" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 22px 0;display:flex;align-items:center;justify-content:space-between"><div style="font:800 22px 'Manrope';letter-spacing:-.02em">Places &amp; zones</div><div style="width:38px;height:38px;border-radius:50%;background:#15807C;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#fff">add</span></div></div>
      <div style="margin:14px 22px 0;height:150px;border-radius:18px;background:linear-gradient(160deg,#E8EFEC,#DCE9E9);position:relative;overflow:hidden;border:1px solid #E4EAE8">
        <div style="position:absolute;left:30px;top:40px;width:80px;height:80px;border-radius:50%;background:rgba(47,158,107,.18);border:2px solid #2F9E6B"></div>
        <div style="position:absolute;left:170px;top:24px;width:96px;height:96px;border-radius:50%;background:rgba(21,128,124,.15);border:2px solid #15807C"></div>
        <div style="position:absolute;left:280px;top:70px;width:70px;height:70px;border-radius:50%;background:rgba(110,102,201,.15);border:2px solid #6E66C9"></div>
      </div>
      <div style="flex:1;overflow:hidden;padding:16px 22px 0">
        <div style="display:flex;flex-direction:column;gap:10px">
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px 16px;display:flex;align-items:center;gap:13px"><div style="width:42px;height:42px;border-radius:13px;background:#EAF5EF;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#2F9E6B">home</span></div><div style="flex:1"><div style="font:700 15px 'Manrope'">Home</div><div style="font:500 12px 'Manrope';color:#8A9893">150 m · 2 inside now</div></div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px 16px;display:flex;align-items:center;gap:13px"><div style="width:42px;height:42px;border-radius:13px;background:#E3EFEE;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#15807C">school</span></div><div style="flex:1"><div style="font:700 15px 'Manrope'">School</div><div style="font:500 12px 'Manrope';color:#8A9893">200 m · Jordan inside</div></div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px 16px;display:flex;align-items:center;gap:13px"><div style="width:42px;height:42px;border-radius:13px;background:#EDE9F7;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#6E66C9">work</span></div><div style="flex:1"><div style="font:700 15px 'Manrope'">Workplace</div><div style="font:500 12px 'Manrope';color:#8A9893">120 m · empty</div></div><div style="width:46px;height:28px;border-radius:16px;background:#DDE5E3;position:relative"><div style="position:absolute;left:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- F6-4 ZONE ACTIVITY LOG -->
<div style="position:absolute;left:1470px;top:6030px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">04 · ZONE ACTIVITY LOG</div>
  <div data-screen-label="Zone activity log" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 22px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">School · activity</span></div>
      <div style="margin:14px 22px 0;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:4px 16px">
        <div style="display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">login</span><div style="flex:1;font:700 13px 'Manrope'">Notify on enter</div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
        <div style="display:flex;align-items:center;gap:12px;padding:13px 0"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">logout</span><div style="flex:1;font:700 13px 'Manrope'">Notify on exit</div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
      </div>
      <div style="flex:1;overflow:hidden;padding:18px 22px 0">
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:0 4px 12px">THIS WEEK</div>
        <div style="display:flex;flex-direction:column;gap:9px">
          <div style="display:flex;align-items:center;gap:12px;background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:12px 15px"><div style="width:34px;height:34px;border-radius:50%;background:#C98A2B;color:#fff;font:800 13px 'Manrope';display:flex;align-items:center;justify-content:center">J</div><div style="flex:1"><div style="font:700 13.5px 'Manrope'"><span style="color:#2F9E6B">Entered</span> · Jordan</div><div style="font:500 11px 'Manrope';color:#8A9893">Thu · on time (8:42 AM)</div></div><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#2F9E6B">login</span></div>
          <div style="display:flex;align-items:center;gap:12px;background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:12px 15px"><div style="width:34px;height:34px;border-radius:50%;background:#C98A2B;color:#fff;font:800 13px 'Manrope';display:flex;align-items:center;justify-content:center">J</div><div style="flex:1"><div style="font:700 13.5px 'Manrope'"><span style="color:#C98A2B">Left</span> · Jordan</div><div style="font:500 11px 'Manrope';color:#8A9893">Wed · 3:10 PM</div></div><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C98A2B">logout</span></div>
          <div style="display:flex;align-items:center;gap:12px;background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:12px 15px"><div style="width:34px;height:34px;border-radius:50%;background:#C98A2B;color:#fff;font:800 13px 'Manrope';display:flex;align-items:center;justify-content:center">J</div><div style="flex:1"><div style="font:700 13.5px 'Manrope'"><span style="color:#2F9E6B">Entered</span> · Jordan</div><div style="font:500 11px 'Manrope';color:#8A9893">Wed · on time (8:39 AM)</div></div><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#2F9E6B">login</span></div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- ===================== FLOW 7 HEADER ===================== -->
<div data-drags-parent="1" style="position:absolute;left:60px;top:7020px;width:1340px;font:800 14px 'JetBrains Mono',monospace;color:#15807C;letter-spacing:.06em">FEATURE SET 07 — HEALTH & WELLNESS · FAMILY CARE</div>

<!-- F7-1 HEALTH DASHBOARD -->
<div style="position:absolute;left:60px;top:7070px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">01 · HEALTH DASHBOARD</div>
  <div data-screen-label="Health dashboard" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 22px 0;display:flex;align-items:center;justify-content:space-between"><div><div style="font:500 13px 'Manrope';color:#5E726F">Thursday, Jun 26</div><div style="font:800 22px 'Manrope';letter-spacing:-.02em">Your health</div></div><div style="width:40px;height:40px;border-radius:50%;background:#15807C;color:#fff;font:800 15px 'Manrope';display:flex;align-items:center;justify-content:center">M</div></div>
      <div style="flex:1;overflow:hidden;padding:14px 22px 0">
        <div style="background:#0C3A3F;border-radius:20px;padding:18px;display:flex;align-items:center;gap:18px;color:#fff">
          <div style="position:relative;width:84px;height:84px;flex:none"><svg width="84" height="84" viewBox="0 0 100 100"><circle cx="50" cy="50" r="42" fill="none" stroke="rgba(255,255,255,.15)" stroke-width="10"></circle><circle cx="50" cy="50" r="42" fill="none" stroke="#5FD0C5" stroke-width="10" stroke-linecap="round" stroke-dasharray="264" stroke-dashoffset="42" transform="rotate(-90 50 50)"></circle></svg><div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center"><span style="font:800 24px 'Manrope'">84</span></div></div>
          <div><div style="font:700 16px 'Manrope'">Health score · Good</div><div style="font:500 12px 'Manrope';color:#9FC4C1;margin-top:5px;line-height:1.45">Active most days, sleep on target. Hydration could improve.</div></div>
        </div>
        <div style="display:flex;gap:10px;margin-top:14px">
          <div style="flex:1;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C">directions_walk</span><div style="font:800 19px 'Manrope';margin-top:6px">8,240</div><div style="font:500 10.5px 'Manrope';color:#8A9893">steps</div></div>
          <div style="flex:1;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C98A2B">local_fire_department</span><div style="font:800 19px 'Manrope';margin-top:6px">410</div><div style="font:500 10.5px 'Manrope';color:#8A9893">kcal</div></div>
          <div style="flex:1;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#2F9E6B">straighten</span><div style="font:800 19px 'Manrope';margin-top:6px">6.1<span style="font-size:11px;color:#8A9893">km</span></div><div style="font:500 10.5px 'Manrope';color:#8A9893">distance</div></div>
        </div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:18px;padding:16px;margin-top:14px">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px"><div style="font:700 13px 'Manrope'">Activity this week</div><div style="font:600 11px 'Manrope';color:#15807C">Steps</div></div>
          <div style="display:flex;align-items:flex-end;justify-content:space-between;height:84px;gap:8px">
            <div style="flex:1;height:50%;background:#BFE0DD;border-radius:5px"></div><div style="flex:1;height:72%;background:#BFE0DD;border-radius:5px"></div><div style="flex:1;height:60%;background:#BFE0DD;border-radius:5px"></div><div style="flex:1;height:88%;background:#BFE0DD;border-radius:5px"></div><div style="flex:1;height:66%;background:#15807C;border-radius:5px"></div><div style="flex:1;height:40%;background:#BFE0DD;border-radius:5px"></div><div style="flex:1;height:30%;background:#BFE0DD;border-radius:5px"></div>
          </div>
        </div>
        <div style="display:flex;gap:10px;margin-top:14px">
          <div style="flex:1;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px;display:flex;align-items:center;gap:10px"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#6E66C9">bedtime</span><div><div style="font:800 16px 'Manrope'">7h 12m</div><div style="font:500 10.5px 'Manrope';color:#8A9893">sleep</div></div></div>
          <div style="flex:1;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px;display:flex;align-items:center;gap:10px"><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#DE3B40">favorite</span><div><div style="font:800 16px 'Manrope'">68<span style="font-size:11px;color:#8A9893"> bpm</span></div><div style="font:500 10.5px 'Manrope';color:#8A9893">resting HR</div></div></div>
        </div>
      </div>
      <div style="background:#fff;border-top:1px solid #EAEEEC;padding:12px 26px 30px;display:flex;align-items:flex-end;justify-content:space-between">
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#9AAAA6"><span style="font-family:'Material Symbols Rounded';font-size:25px">map</span><span style="font:600 10px 'Manrope'">Map</span></div>
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#15807C"><span style="font-family:'Material Symbols Rounded';font-size:25px;font-variation-settings:'FILL' 1">favorite</span><span style="font:700 10px 'Manrope'">Health</span></div>
        <div style="width:64px;height:64px;border-radius:50%;background:#DE3B40;display:flex;flex-direction:column;align-items:center;justify-content:center;margin-top:-40px;border:4px solid #fff;box-shadow:0 8px 18px rgba(222,59,64,.4)"><span style="font:800 15px 'Manrope';color:#fff">SOS</span></div>
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#9AAAA6"><span style="font-family:'Material Symbols Rounded';font-size:25px">monitoring</span><span style="font:600 10px 'Manrope'">Insights</span></div>
        <div style="display:flex;flex-direction:column;align-items:center;gap:3px;color:#9AAAA6"><span style="font-family:'Material Symbols Rounded';font-size:25px">shield_person</span><span style="font:600 10px 'Manrope'">Privacy</span></div>
      </div>
    </div>
  </div>
</div>

<!-- F7-2 HEALTH REPORT -->
<div style="position:absolute;left:530px;top:7070px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">02 · WEEKLY / MONTHLY REPORT</div>
  <div data-screen-label="Health report" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 22px 0;display:flex;align-items:center;justify-content:space-between"><div style="display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">Weekly report</span></div><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#15807C">ios_share</span></div>
      <div style="flex:1;overflow:hidden;padding:16px 22px 0">
        <div style="font:500 13px 'Manrope';color:#8A9893">Jun 20 – Jun 26</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:18px;padding:18px;margin-top:12px">
          <div style="display:flex;justify-content:space-between;text-align:center">
            <div><div style="font:800 24px 'Manrope';color:#0C3A3F">9,120</div><div style="font:500 11px 'Manrope';color:#8A9893">avg steps</div><div style="font:600 11px 'Manrope';color:#2F9E6B;margin-top:3px">▲ 6%</div></div>
            <div><div style="font:800 24px 'Manrope';color:#0C3A3F">7h 4m</div><div style="font:500 11px 'Manrope';color:#8A9893">avg sleep</div><div style="font:600 11px 'Manrope';color:#2F9E6B;margin-top:3px">▲ 12m</div></div>
            <div><div style="font:800 24px 'Manrope';color:#0C3A3F">2,840</div><div style="font:500 11px 'Manrope';color:#8A9893">avg kcal</div><div style="font:600 11px 'Manrope';color:#C98A2B;margin-top:3px">▼ 3%</div></div>
          </div>
        </div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:18px;padding:18px;margin-top:14px">
          <div style="font:700 13px 'Manrope';margin-bottom:14px">Steps per day</div>
          <div style="display:flex;align-items:flex-end;justify-content:space-between;height:130px;gap:9px">
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:70%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">M</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:85%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">T</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:62%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">W</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:100%;background:#15807C;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#15807C">T</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:74%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">F</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:48%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">S</span></div>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end"><div style="width:100%;height:40%;background:#BFE0DD;border-radius:6px"></div><span style="font:600 10px 'Manrope';color:#8A9893">S</span></div>
          </div>
        </div>
        <div style="margin-top:14px;background:#E3EFEE;border-radius:14px;padding:14px 16px;display:flex;gap:11px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#15807C">auto_awesome</span><div style="font:500 12.5px 'Manrope';color:#1B6A66;line-height:1.5"><b>Insight:</b> Thursday was your most active day. Sleep improved after earlier bedtimes mid-week.</div></div>
      </div>
    </div>
  </div>
</div>

<!-- F7-3 FAMILY HEALTH OVERVIEW -->
<div style="position:absolute;left:1000px;top:7070px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">03 · FAMILY HEALTH OVERVIEW</div>
  <div data-screen-label="Family health" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 22px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:800 20px 'Manrope';letter-spacing:-.02em">Family wellness</span></div>
      <div style="flex:1;overflow:hidden;padding:16px 22px 0">
        <div style="font:500 12px 'Manrope';color:#8A9893;margin:0 4px 10px;line-height:1.4">Only members who share wellness appear here. It's always mutual.</div>
        <div style="display:flex;flex-direction:column;gap:10px">
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px 16px;display:flex;align-items:center;gap:13px"><div style="width:44px;height:44px;border-radius:50%;background:#C98A2B;color:#fff;font:800 15px 'Manrope';display:flex;align-items:center;justify-content:center">J</div><div style="flex:1"><div style="font:700 15px 'Manrope'">Jordan</div><div style="font:500 11.5px 'Manrope';color:#2F9E6B">Active now · 9,200 steps</div></div><div style="text-align:right"><div style="font:800 17px 'Manrope';color:#2F9E6B">88</div><div style="font:500 10px 'Manrope';color:#8A9893">wellness</div></div></div>
          <div style="background:#fff;border:1px solid #EFDFBF;border-radius:16px;padding:14px 16px;display:flex;align-items:center;gap:13px"><div style="width:44px;height:44px;border-radius:50%;background:#6E66C9;color:#fff;font:800 15px 'Manrope';display:flex;align-items:center;justify-content:center">G</div><div style="flex:1"><div style="font:700 15px 'Manrope'">Grandpa</div><div style="font:500 11.5px 'Manrope';color:#C98A2B">Low activity today · 740 steps</div></div><div style="text-align:right"><div style="font:800 17px 'Manrope';color:#C98A2B">61</div><div style="font:500 10px 'Manrope';color:#8A9893">wellness</div></div></div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:14px 16px;display:flex;align-items:center;gap:13px"><div style="width:44px;height:44px;border-radius:50%;background:#6E66C9;color:#fff;font:800 15px 'Manrope';display:flex;align-items:center;justify-content:center">D</div><div style="flex:1"><div style="font:700 15px 'Manrope'">Dad</div><div style="font:500 11.5px 'Manrope';color:#2F9E6B">Active · 11,400 steps</div></div><div style="text-align:right"><div style="font:800 17px 'Manrope';color:#2F9E6B">91</div><div style="font:500 10px 'Manrope';color:#8A9893">wellness</div></div></div>
        </div>
        <div style="font:700 11px 'JetBrains Mono';color:#C42A30;letter-spacing:.06em;margin:18px 4px 10px">ELDERLY-CARE ALERT</div>
        <div style="background:#fff;border:1px solid #EFDFBF;border-left:4px solid #C98A2B;border-radius:16px;padding:15px 16px;display:flex;gap:12px"><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#C98A2B">motion_photos_paused</span><div style="flex:1"><div style="font:700 14px 'Manrope';color:#8A6118">Grandpa — unusual routine</div><div style="font:500 12px 'Manrope';color:#5E726F;margin-top:3px;line-height:1.45">Much less movement than his usual mornings. Tap to check in.</div></div></div>
      </div>
    </div>
  </div>
</div>

<!-- F7-4 ELDERLY CARE ALERT -->
<div style="position:absolute;left:1470px;top:7070px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#C98A2B;letter-spacing:.04em;margin:0 0 12px 6px">04 · ELDERLY-CARE · ABNORMAL PATTERN</div>
  <div data-screen-label="Elderly care alert" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#FBF3E3;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 22px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px;color:#8A6118">arrow_back</span></div>
      <div style="flex:1;overflow:hidden;padding:14px 26px 0;text-align:center;display:flex;flex-direction:column;align-items:center">
        <div style="width:78px;height:78px;border-radius:24px;background:#C98A2B;display:flex;align-items:center;justify-content:center;box-shadow:0 10px 24px rgba(201,138,43,.3)"><span style="font-family:'Material Symbols Rounded';font-size:42px;color:#fff">elderly</span></div>
        <div style="font:800 24px 'Manrope';margin-top:20px;color:#8A6118;letter-spacing:-.01em">Unusual routine — Grandpa</div>
        <div style="background:#fff;border:1px solid #EFDFBF;border-radius:16px;padding:15px 16px;margin-top:18px;text-align:left;display:flex;gap:11px"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C98A2B">auto_awesome</span><div style="font:500 13px 'Manrope';color:#8A6118;line-height:1.5"><b>Why we're flagging this:</b> no movement detected since 9:00 AM. He's usually active by 7:30 and has left home by now on weekdays.</div></div>
        <div style="width:100%;background:#fff;border:1px solid #EFDFBF;border-radius:16px;padding:6px 18px;margin-top:12px;text-align:left">
          <div style="display:flex;align-items:center;gap:12px;padding:12px 0;border-bottom:1px solid #F3E8CF"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#8A6118">schedule</span><div style="flex:1;font:600 13px 'Manrope';color:#8A6118">Last movement</div><span style="font:700 13px 'Manrope'">9:02 AM</span></div>
          <div style="display:flex;align-items:center;gap:12px;padding:12px 0;border-bottom:1px solid #F3E8CF"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#8A6118">home</span><div style="flex:1;font:600 13px 'Manrope';color:#8A6118">Location</div><span style="font:700 13px 'Manrope'">Home</span></div>
          <div style="display:flex;align-items:center;gap:12px;padding:12px 0"><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#8A6118">battery_5_bar</span><div style="flex:1;font:600 13px 'Manrope';color:#8A6118">Phone battery</div><span style="font:700 13px 'Manrope'">82%</span></div>
        </div>
      </div>
      <div style="padding:14px 26px 40px;display:flex;flex-direction:column;gap:11px">
        <div style="background:#2F9E6B;color:#fff;font:700 16px 'Manrope';padding:17px;border-radius:16px;text-align:center;display:flex;align-items:center;justify-content:center;gap:9px"><span style="font-family:'Material Symbols Rounded';font-size:21px">call</span>Call Grandpa</div>
        <div style="display:flex;gap:11px"><div style="flex:1;background:#fff;border:1.5px solid #EFDFBF;color:#8A6118;font:700 14px 'Manrope';padding:14px;border-radius:16px;text-align:center">Send check-in</div><div style="flex:1;background:#fff;border:1.5px solid #EFDFBF;color:#8A6118;font:700 14px 'Manrope';padding:14px;border-radius:16px;text-align:center">Mark OK</div></div>
      </div>
    </div>
  </div>
</div>

<!-- F7-5 FAMILY OVERVIEW DASHBOARD -->
<div style="position:absolute;left:1940px;top:7070px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">05 · FAMILY OVERVIEW DASHBOARD</div>
  <div data-screen-label="Family overview" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 22px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:800 20px 'Manrope';letter-spacing:-.02em">Family overview</span></div>
      <div style="flex:1;overflow:hidden;padding:16px 22px 0">
        <div style="display:flex;gap:10px">
          <div style="flex:1;background:#EAF5EF;border:1px solid #CDE9DA;border-radius:16px;padding:15px"><div style="font:800 24px 'Manrope';color:#1E6E4B">88</div><div style="font:500 11px 'Manrope';color:#4E876C">avg safety</div></div>
          <div style="flex:1;background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:15px"><div style="font:800 24px 'Manrope'">4</div><div style="font:500 11px 'Manrope';color:#8A9893">in circle</div></div>
          <div style="flex:1;background:#FBF3E3;border:1px solid #EFDFBF;border-radius:16px;padding:15px"><div style="font:800 24px 'Manrope';color:#8A6118">1</div><div style="font:500 11px 'Manrope';color:#A57A2E">to check</div></div>
        </div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:18px 4px 10px">MEMBER SAFETY</div>
        <div style="display:flex;flex-direction:column;gap:8px">
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:11px 14px;display:flex;align-items:center;gap:11px"><div style="width:34px;height:34px;border-radius:50%;background:#C98A2B;color:#fff;font:800 13px 'Manrope';display:flex;align-items:center;justify-content:center">J</div><div style="flex:1;font:700 13.5px 'Manrope'">Jordan</div><div style="width:80px;height:7px;background:#EDF1F0;border-radius:4px;overflow:hidden"><div style="width:90%;height:100%;background:#2F9E6B"></div></div><span style="font:700 12px 'Manrope';color:#1E6E4B">90</span></div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:11px 14px;display:flex;align-items:center;gap:11px"><div style="width:34px;height:34px;border-radius:50%;background:#6E66C9;color:#fff;font:800 13px 'Manrope';display:flex;align-items:center;justify-content:center">G</div><div style="flex:1;font:700 13.5px 'Manrope'">Grandpa</div><div style="width:80px;height:7px;background:#EDF1F0;border-radius:4px;overflow:hidden"><div style="width:61%;height:100%;background:#C98A2B"></div></div><span style="font:700 12px 'Manrope';color:#8A6118">61</span></div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:14px;padding:11px 14px;display:flex;align-items:center;gap:11px"><div style="width:34px;height:34px;border-radius:50%;background:#6E66C9;color:#fff;font:800 13px 'Manrope';display:flex;align-items:center;justify-content:center">D</div><div style="flex:1;font:700 13.5px 'Manrope'">Dad</div><div style="width:80px;height:7px;background:#EDF1F0;border-radius:4px;overflow:hidden"><div style="width:94%;height:100%;background:#2F9E6B"></div></div><span style="font:700 12px 'Manrope';color:#1E6E4B">94</span></div>
        </div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:18px;padding:16px;margin-top:14px">
          <div style="font:700 13px 'Manrope';margin-bottom:12px">Combined activity</div>
          <svg viewBox="0 0 300 80" style="width:100%;height:64px"><polyline points="0,60 40,48 80,52 120,30 160,38 200,20 240,28 300,14" fill="none" stroke="#15807C" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"></polyline><polyline points="0,70 40,66 80,60 120,58 160,50 200,52 240,44 300,40" fill="none" stroke="#C98A2B" stroke-width="3" stroke-dasharray="4 5" stroke-linecap="round"></polyline></svg>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- ===================== FLOW 8 HEADER ===================== -->
<div data-drags-parent="1" style="position:absolute;left:60px;top:8110px;width:1340px;font:800 14px 'JetBrains Mono',monospace;color:#15807C;letter-spacing:.06em">FEATURE SET 08 — SETTINGS</div>

<!-- F8-1 SETTINGS -->
<div style="position:absolute;left:60px;top:8160px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">01 · SETTINGS</div>
  <div data-screen-label="Settings" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:10px 22px 0"><div style="font:800 22px 'Manrope';letter-spacing:-.02em">Settings</div></div>
      <div style="flex:1;overflow:hidden;padding:16px 22px 0">
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:18px;padding:16px;display:flex;align-items:center;gap:14px"><div style="width:52px;height:52px;border-radius:50%;background:#15807C;color:#fff;font:800 19px 'Manrope';display:flex;align-items:center;justify-content:center">M</div><div style="flex:1"><div style="font:700 16px 'Manrope'">Maya Rivera</div><div style="font:500 12px 'Manrope';color:#8A9893">Guardian · The Rivera Family</div></div><span style="font-family:'Material Symbols Rounded';font-size:22px;color:#C5CFCC">chevron_right</span></div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:18px 4px 10px">CIRCLE</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:2px 16px">
          <div style="display:flex;align-items:center;gap:13px;padding:13px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">manage_accounts</span><div style="flex:1;font:600 14px 'Manrope'">Roles &amp; permissions</div><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C5CFCC">chevron_right</span></div>
          <div style="display:flex;align-items:center;gap:13px;padding:13px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">contact_emergency</span><div style="flex:1;font:600 14px 'Manrope'">Emergency contacts</div><span style="font:600 12px 'Manrope';color:#8A9893">3</span><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C5CFCC">chevron_right</span></div>
          <div style="display:flex;align-items:center;gap:13px;padding:13px 0"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">vpn_key</span><div style="flex:1;font:600 14px 'Manrope'">Silent / duress mode</div><span style="font:600 11px 'Manrope';color:#2F9E6B;background:#EAF5EF;padding:3px 9px;border-radius:7px">On</span></div>
        </div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:18px 4px 10px">PREFERENCES</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:2px 16px">
          <div style="display:flex;align-items:center;gap:13px;padding:13px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">notifications</span><div style="flex:1;font:600 14px 'Manrope'">Notifications</div><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C5CFCC">chevron_right</span></div>
          <div style="display:flex;align-items:center;gap:13px;padding:13px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">shield_person</span><div style="flex:1;font:600 14px 'Manrope'">Privacy &amp; sharing</div><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C5CFCC">chevron_right</span></div>
          <div style="display:flex;align-items:center;gap:13px;padding:13px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">watch</span><div style="flex:1;font:600 14px 'Manrope'">Connected devices</div><span style="font:600 12px 'Manrope';color:#8A9893">2</span><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C5CFCC">chevron_right</span></div>
          <div style="display:flex;align-items:center;gap:13px;padding:13px 0"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#15807C">text_fields</span><div style="flex:1;font:600 14px 'Manrope'">Text size &amp; display</div><span style="font:600 12px 'Manrope';color:#8A9893">Large</span><span style="font-family:'Material Symbols Rounded';font-size:20px;color:#C5CFCC">chevron_right</span></div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- F8-2 CONNECTED DEVICES -->
<div style="position:absolute;left:530px;top:8160px;width:410px">
  <div data-drags-parent="1" style="font:600 12px 'JetBrains Mono',monospace;color:#5E726F;letter-spacing:.04em;margin:0 0 12px 6px">02 · CONNECTED HEALTH DEVICES</div>
  <div data-screen-label="Connected devices" style="width:410px;height:864px;background:#0B262A;border-radius:54px;padding:10px;box-shadow:0 30px 60px -22px rgba(12,58,63,.45)">
    <div style="width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;background:#ECF0EF;display:flex;flex-direction:column">
      <div style="height:50px;display:flex;align-items:center;justify-content:space-between;padding:14px 26px 0;font:600 15px 'Manrope'"><span>9:41</span><span style="display:flex;gap:7px;font-size:17px"><span style="font-family:'Material Symbols Rounded'">signal_cellular_alt</span><span style="font-family:'Material Symbols Rounded'">wifi</span><span style="font-family:'Material Symbols Rounded'">battery_full</span></span></div>
      <div style="padding:8px 22px 0;display:flex;align-items:center;gap:14px"><span style="font-family:'Material Symbols Rounded';font-size:26px">arrow_back</span><span style="font:700 17px 'Manrope'">Connected devices</span></div>
      <div style="flex:1;overflow:hidden;padding:16px 22px 0">
        <div style="display:flex;flex-direction:column;gap:10px">
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:15px 16px;display:flex;align-items:center;gap:13px"><div style="width:44px;height:44px;border-radius:13px;background:#15302E;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#fff">watch</span></div><div style="flex:1"><div style="font:700 15px 'Manrope'">Apple Watch</div><div style="font:500 11.5px 'Manrope';color:#2F9E6B">Synced 2 min ago · 76%</div></div><span style="font:600 11px 'Manrope';color:#2F9E6B;background:#EAF5EF;padding:5px 10px;border-radius:8px">Active</span></div>
          <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:15px 16px;display:flex;align-items:center;gap:13px"><div style="width:44px;height:44px;border-radius:13px;background:#0C3A3F;display:flex;align-items:center;justify-content:center"><span style="font-family:'Material Symbols Rounded';font-size:24px;color:#5FD0C5">fitness_center</span></div><div style="flex:1"><div style="font:700 15px 'Manrope'">Fitbit Charge</div><div style="font:500 11.5px 'Manrope';color:#8A9893">Last sync 1h ago · 54%</div></div><span style="font:600 11px 'Manrope';color:#2F9E6B;background:#EAF5EF;padding:5px 10px;border-radius:8px">Active</span></div>
          <div style="background:#fff;border:1.5px dashed #C5CFCC;border-radius:16px;padding:15px 16px;display:flex;align-items:center;gap:13px;color:#15807C"><span style="font-family:'Material Symbols Rounded';font-size:24px">add_circle</span><div style="font:700 14px 'Manrope'">Add a device</div></div>
        </div>
        <div style="font:700 11px 'JetBrains Mono';color:#8A9893;letter-spacing:.06em;margin:20px 4px 10px">DATA THESE DEVICES SHARE</div>
        <div style="background:#fff;border:1px solid #E4EAE8;border-radius:16px;padding:2px 16px">
          <div style="display:flex;align-items:center;gap:13px;padding:14px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#DE3B40">favorite</span><div style="flex:1;font:600 14px 'Manrope'">Heart rate</div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="display:flex;align-items:center;gap:13px;padding:14px 0;border-bottom:1px solid #F0F3F2"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#6E66C9">bedtime</span><div style="flex:1;font:600 14px 'Manrope'">Sleep</div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
          <div style="display:flex;align-items:center;gap:13px;padding:14px 0"><span style="font-family:'Material Symbols Rounded';font-size:21px;color:#2F9E6B">directions_walk</span><div style="flex:1;font:600 14px 'Manrope'">Steps &amp; activity</div><div style="width:46px;height:28px;border-radius:16px;background:#15807C;position:relative"><div style="position:absolute;right:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff"></div></div></div>
        </div>
      </div>
    </div>
  </div>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props="{&quot;$preview&quot;:{&quot;width&quot;:1400,&quot;height&quot;:900}}">
class Component extends DCLogic {
  state = { hold: 0, armed: false };
  _cancelTapGuard = false;
  _cancelTapGuardTimer = null;

  clearCancelTapGuard = () => {
    if (this._cancelTapGuardTimer != null) {
      clearTimeout(this._cancelTapGuardTimer);
      this._cancelTapGuardTimer = null;
    }
    this._cancelTapGuard = false;
  };

  startHold = () => {
    if (this.state.armed) return;
    this.clearCancelTapGuard();
    this._t0 = performance.now();
    const loop = () => {
      const e = (performance.now() - this._t0) / 3000;
      const h = Math.min(1, e);
      if (h >= 1) {
        this.setState({ hold: 1, armed: true });
        // Swallow the release-generated click from the hold gesture so the
        // armed state survives long enough for an intentional follow-up tap.
        this._cancelTapGuard = true;
        this._cancelTapGuardTimer = setTimeout(() => {
          this._cancelTapGuard = false;
          this._cancelTapGuardTimer = null;
        }, 0);
        return;
      }
      this.setState({ hold: h });
      this._raf = requestAnimationFrame(loop);
    };
    this._raf = requestAnimationFrame(loop);
  };

  endHold = () => {
    if (this.state.armed) return;
    cancelAnimationFrame(this._raf);
    this.setState({ hold: 0 });
    this.clearCancelTapGuard();
  };

  resetSos = () => {
    if (this._cancelTapGuard) return;
    cancelAnimationFrame(this._raf);
    this.clearCancelTapGuard();
    this.setState({ hold: 0, armed: false });
  };

  componentWillUnmount() {
    cancelAnimationFrame(this._raf);
    this.clearCancelTapGuard();
  }

  renderVals() {
    const C = 2 * Math.PI * 46; // r=46
    const hold = this.state.hold;
    const ringOffset = C * (1 - hold);
    const ringColor = hold > 0.6 ? '#DE3B40' : '#5FD0C5';
    const holdPct = Math.round(hold * 100);
    return {
      ringOffset,
      ringColor,
      ringDash: C,
      holdPct,
      armed: this.state.armed,
      notArmed: !this.state.armed,
      holdLabel: this.state.armed ? 'SENT' : 'SOS',
      onHoldStart: this.startHold,
      onHoldEnd: this.endHold,
      resetSos: this.resetSos
    };
  }
}
</script>
</body>
</html>
