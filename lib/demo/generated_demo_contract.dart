// Generated from shared/demo_contract.json. Do not edit.
// dart format off
const demoServiceUuid = '7df20000-4e55-4447-4500-4e5544474531';
const demoCommandUuid = '7df20001-4e55-4447-4500-4e5544474531';
const demoStateUuid = '7df20002-4e55-4447-4500-4e5544474531';
const demoDeviceNames = <String,String>{'orbit':'Nudge Orbit Demo','station':'Nudge Station Demo'};
const demoActions = <String>["next","restart","startFocus"];
const demoSceneNames = <String>["boot","home","ready","focus","encouragement","complete","growth","summary"];
const demoScenePoses = <String>["idle","idle","ready","focus","support","complete","growth","idle"];
const demoPalette = <String,int>{'background':0xff081018,'primary':0xff8B69FF,'ready':0xffBDAAFF,'paused':0xffF0B356,'complete':0xff5AD2BD,'support':0xff4AD2EF,'text':0xffF7F7EF,'muted':0xff6B7D94};
class DemoMark { const DemoMark(this.kind,this.x,this.y,this.a,this.b,this.ink); final String kind,ink; final int x,y,a,b; }
const demoPoseMarks = <String,List<DemoMark>>{
'idle':[DemoMark('circle',32,43,14,0,'ready'),DemoMark('line',32,29,32,13,'ready'),DemoMark('line',32,20,14,14,'ready'),DemoMark('line',32,18,50,12,'ready'),DemoMark('circle',26,41,2,0,'background'),DemoMark('circle',38,41,2,0,'background'),DemoMark('line',28,49,36,49,'background')],
'ready':[DemoMark('circle',32,43,14,0,'ready'),DemoMark('line',32,29,32,13,'ready'),DemoMark('line',32,20,14,10,'ready'),DemoMark('line',32,18,50,8,'ready'),DemoMark('circle',26,38,2,0,'background'),DemoMark('circle',38,38,2,0,'background'),DemoMark('line',28,49,36,49,'background')],
'focus':[DemoMark('circle',32,43,14,0,'primary'),DemoMark('line',32,29,32,13,'primary'),DemoMark('line',32,20,14,14,'primary'),DemoMark('line',32,18,50,12,'primary'),DemoMark('line',24,41,29,41,'background'),DemoMark('line',35,41,40,41,'background'),DemoMark('line',28,49,36,49,'background')],
'support':[DemoMark('circle',32,43,14,0,'support'),DemoMark('line',32,29,32,13,'support'),DemoMark('line',32,20,14,14,'support'),DemoMark('line',32,18,50,12,'support'),DemoMark('circle',28,41,2,0,'background'),DemoMark('circle',40,41,2,0,'background'),DemoMark('line',26,49,32,52,'background'),DemoMark('line',32,52,38,49,'background'),DemoMark('circle',55,34,2,0,'support'),DemoMark('circle',59,30,1,0,'support')],
'complete':[DemoMark('circle',32,43,14,0,'complete'),DemoMark('line',32,29,32,13,'complete'),DemoMark('line',32,20,14,14,'complete'),DemoMark('line',32,18,50,12,'complete'),DemoMark('line',32,26,53,22,'complete'),DemoMark('circle',26,41,2,0,'background'),DemoMark('circle',38,41,2,0,'background'),DemoMark('line',26,49,32,52,'background'),DemoMark('line',32,52,38,49,'background')],
'growth':[DemoMark('circle',32,43,14,0,'complete'),DemoMark('line',32,29,32,13,'complete'),DemoMark('line',32,20,14,14,'complete'),DemoMark('line',32,18,50,12,'complete'),DemoMark('line',32,26,53,22,'complete'),DemoMark('line',32,25,12,24,'complete'),DemoMark('circle',26,41,2,0,'background'),DemoMark('circle',38,41,2,0,'background'),DemoMark('line',26,49,32,52,'background'),DemoMark('line',32,52,38,49,'background')],
};
