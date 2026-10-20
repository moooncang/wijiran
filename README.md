# 위지란 — 본편 (합벽)

2D 액션 본편의 Godot 4.7 프로젝트. 체험판(`../godot`)의 전투 코드를 가져와 본편 구조로 재편했다. 기획은 `docs/`(본편 1막 구상안, 장법 시스템, 플레이어 전투, 목각교두, 세계관).

## 실행
- 에디터/실행: `Godot --path .` (뷰포트 800×450, 창 1280×720, 물리 120Hz)
- 테스트: `Godot --headless --path . -- --test=all` (`palm|save|projectile|room|checkpoint|tianel`). 저장 파일을 건드리지 않는다.
- 특정 맵에서 시작: `-- --level=f1 --spawn=start`. 저장 초기화: `-- --wipe`. 터치 UI 강제: `-- --touch`. 보스 시드: `--seed=N`.
- 웹 내보내기: 프리셋 `Web` → `site/play/`, `WebMobile`(터치 UI, 가로 고정 셸) → `site/mobile/`.

## 조작
A/D 이동 · W 점프/허공답월 · Shift 마우스 방향 잔월보 · Space 패링 · 좌클릭/J 장법 3연계 · E 강화 초식 · **우클릭/F 월인(적 당기기·보스면 내가 끌려감, 내공 20·3초)** · Q 월식 · ↑/W 상호작용(문·비급·휴식) · Tab 장법 메뉴 · R 체크포인트로

## 구조
```
src/autoload/   anim_data(시트·manifest 로더)  juice(히트스톱·이펙트·잔상)  game(저장·체크포인트·플래그·장법 장착·일시정지)
src/combat/     combat_config  combat_resolver  hit_event  enemy_status  palm_styles(장법 4종 데이터)
src/player/     player(이동·3연계·강화·패링·대시·월식; 장법은 PalmStyles에서 읽음)  touch_controls
src/enemies/    enemy_base(상태·피격·패링 훅·HP바)  soldier(검병: 단타/예고 연격)  scout_archer(정찰병: 조준→사격→1회 후퇴, 화면 밖 사격 금지)  projectile(화살: 패링 가능, 결과 회신)  dummy
src/boss/       boss_base(패턴 러너: F/B/MOVE/PROJ/WAVE 판정, 붉은 도트 예고, 60% 후기 연계, 변주, 기절·격파)  tianel(B1 녹궁대장)  boss_mokgak(목각교두: 체험판 보스, T0 패링 연습 모드)
src/world/      level(데이터 → 바닥·발판·엄폐·소품·구역; 봉쇄 구역·카메라 구획)  checkpoint  door  manual_pickup(비급)  rest_point  sign  game_camera  backdrop  fx/ghost/flash
src/ui/         hud  boss_hud  dialogue(상단 말풍선 큐)  palm_menu(Tab)
levels/         t0_yard  f1_forest  b1_clearing  h0_inn (맵 = 데이터 딕셔너리)
tests/          selftests(헤드리스 수락 테스트)
```

## 규칙 (기획 반영)
- 타격 시각은 데이터, 애니메이션은 거기에 맞춘다. 예고는 판정과 1:1(붉은 반투명 도트), 색만으로 구분하지 않는다(머리 위 !/!!/X).
- 장법: 슬롯 1개, 비급은 고정 배치·영구·자동 장착 없음, 장착은 휴식 지점에서 중립 상태일 때만, 콤보 상태만 초기화. 반격 자격은 `combo_index == 0`, 과열·침식은 `is_heavy`로 판정. 미지 ID·미보유 장착은 흑월장으로 복구.
- 저장: 비급·보스 격파·체크포인트 이전 구역 정리는 영구, 체크포인트 이후 구역 정리는 세션(사망 시 초기화). 보스 앞 첫 도착 때 자원 스냅샷을 찍고 재도전마다 복원.
- 원거리 적은 화면 밖에서 사격을 시작하지 않고, 후퇴를 연속하지 않는다. 티아넬은 이동 패턴 뒤에 반드시 제자리 패턴이 온다.
- 전멸전 봉쇄 구역은 맵당 최대 2개(F1: r1, r3). 나머지는 지나갈 수 있다.

## 2차 조정 (2026-10-20b)
- 월인: 우클릭이 강화 초식에서 분리된 새 기술. 조준 원뿔 안 가장 가까운 적을 0.16초에 끌어오고 행동을 끊는다(정찰병 조준 취소). 보스는 못 움직이므로 주인공이 끌려간다(무적 없음).
- 튜토리얼 T0는 기술 없이는 못 지난다: 115px 벽(허공답월), 천장 60px 아래 150px 구덩이(지상 잔월보), 180px 절벽(공중 잔월보 위로). 구덩이 낙하는 마지막 발판으로 복귀.
- 티아넬 2차: HP 900, 판단 0.32초(후기 0.18), 패턴 6종(바람 두 발·다섯 갈래 잎·양방향 뿌리 파문 2회·가지 바꾸기+3갈래·잿비(7칸 중 5칸 낙하)·질풍 질주), 모든 패턴이 연계. 보스 이펙트 2.2배(fx_scale).

## 10차 에셋 연결 (2026-10-20)
`assets/r10/`: 배경(원·중·근경 패럴랙스 + 바닥 표면 타일 + 지형 조각 + 장식), 정찰병(엘프/인간, 같은 AI·앵커), 티아넬 16클립(당김 자세 홀드 → 이벤트에 맞춰 release/impact), 화살·잿비·뿌리 파문·질풍 질주 이펙트(판정 크기 그대로, fx_scale 1), 장법 3종 이펙트(회란 환장은 앞뒤 2겹), 월인(실·갈고리·끌림), 소품(체크포인트·문·비급·휴식·표지·표적·제자 표식), 초상·대화 틀·장법 메뉴 패널·아이콘·맵 제목 띠, NPC(제자 2·레나타), 연출 컷(출정·경로, 처음 1회).
- 로더: `Anim.tex()`는 v9/r10(및 terrain/, ui/)을 차례로 찾는다. 맵은 `map_key` + `art`(발판 번호 → 지형 조각) + `decor`로 그림을 붙인다. `ClipSprite`가 시트 클립(hold_last, frame_durations, 앵커)을 재생한다.

## 현재 범위
T0 → F1 → B1 → H0(거점). 검병만 체험판 56px 시트. 에셋 요청서는 `design/10차-납품-요청-본편-1구간.md`. 웹 빌드는 `docs/play`(PC)·`docs/mobile`(터치)로 GitHub Pages에 올린다. 다음: F2·B2(미레유)·F3·B3(엘로디).
