function info = kah_info
info = struct;

% path to data on shared VoytekLab server
info.path.kah = '/Volumes/voyteklab/common/data2/kahana_ecog_RAMphase1/';
info.path.demfile = [info.path.kah 'Release_Metadata_20160930/RAM_subject_demographics.csv'];

% current release of Kahana data
info.release = 'r1';
info.path.data = [info.path.kah 'session_data/experiment_data/protocols/' info.release '/subjects/'];

% selected subjects for aging directional PAC + 1/f slope study
% selected based on output of kah_parsemetadata.m
% >= age 18, sampling rate >= 500 Hz, temporal & frontal grids, FR1 task, >
% 20 correct trials
info.subj = {'R1032D', 'R1006P', 'R1086M', 'R1177M', 'R1128E', 'R1156D', 'R1039M', 'R1149N', 'R1034D', 'R1112M', ...
    'R1162N', 'R1033D', 'R1167M', 'R1102P', 'R1121M', 'R1175N', 'R1060M', 'R1089P', 'R1154D', 'R1003P', ...
    'R1053M', 'R1066P', 'R1068J', 'R1127P', 'R1159P', 'R1080E', 'R1142N', 'R1059J', 'R1067P', 'R1018P', ...
    'R1135E', 'R1147P', 'R1001P', 'R1020J', 'R1002P', 'R1036M', 'R1045E'};
    

% selected subjects' age, extracted from info.path.demfile
info.age = [19, 20, 20, 23, 26, 27, 28, 28, 29, 29, 30, 31, 33, 34, 34, 34, 36, 36, 36, 39, 39, 39, 39, 40, 42, 43, 43, 44, 45, 47, 47, 47, 48, 48, 49, 49, 51];
    
% for each subject, extract experiments and sessions and store header,
% data, and event paths
for isubj = 1:numel(info.subj)
    subjcurr = info.subj{isubj};
    subjpath = [info.path.data subjcurr '/'];

    experiments = extractfield(dir([subjpath 'experiments/']), 'name');
    experiments(contains(experiments, '.')) = [];
    
    for iexp = 1:numel(experiments)
        expcurr = experiments{iexp};
        
        sessions = extractfield(dir([subjpath 'experiments/' expcurr '/sessions/']), 'name');
        sessions(contains(sessions, '.')) = [];
        
        for isess = 1:numel(sessions)
            info.(subjcurr).(expcurr).session(isess).headerfile = [subjpath 'experiments/' expcurr '/sessions/' sessions{isess} '/behavioral/current_processed/index.json'];
            info.(subjcurr).(expcurr).session(isess).datadir = [subjpath 'experiments/' expcurr '/sessions/' sessions{isess} '/ephys/current_processed/noreref/'];
            info.(subjcurr).(expcurr).session(isess).eventfile = [subjpath 'experiments/' expcurr '/sessions/' sessions{isess} '/behavioral/current_processed/task_events.json'];
        end
    end
end
% remove specific ones with problems
info.R1156D.FR1.session(4) = [];

%%%%%% R1032D %%%%% ***
% Mostly depth electrodes. Relatively frequent epileptic events, especially
% in depths. Very buzzy (reference noise?), removed by average referencing.
% Overall, not too bad.

info.R1032D.FR1.session(1).bsfilt.peak      = [60, 63.8, 120.1, 180, 240.1]; % Session 1 (z-thresh 2)
info.R1032D.FR1.session(1).bsfilt.halfbandw = [0.5, 0.5, 0.5,   0.5, 0.5]; % Session 1 (z-thresh 2)

info.R1032D.FR1.session(1).badchan.broken = {'LFS8x', 'LID12', 'LOFD12', 'LOTD12', 'LTS8x', 'RID12', 'ROFD12', 'ROTD12', 'RTS8x', ... % flat-line channels
    };
% IGNORED b/c favoring keeping channels; info.R1032D.FR1.session(1).badchan.epileptic = {
%     'LFS1x', 'LFS2x', 'LFS3x', 'LFS4x', ... % Large deviations, many related to epileptic activity in depths
%     };
info.R1032D.FR1.session(1).badchan.epileptic = {};
info.R1032D.FR1.session(1).badsegment = [6692,7487;13550,14138;16620,17202;22614,23776;50403,51060;76023,79445;105550,106673;109098,109835;111814,112641;130627,131144;200285,200602;201414,201744;209220,209679;212756,215299;219092,219596;250892,251686;259595,260415;266788,267557;292356,292866;296059,297176;318349,319531;323672,324570;344181,344550;348124,349557;357439,357969;382427,383111;402069,403201;412014,412654;428382,429360;437782,438486;455788,456189;498574,499487;506866,508486;510852,511511;527982,528376;539098,539647;575342,575946;594846,595189;605395,605879;687833,688131;693808,694351;751459,751996;771666,772157;811162,811570;815672,816009;853027,853512;860537,861467;890382,891183;920767,921644;922143,923377;926197,927739;959846,960559;966434,966932;976575,976783;985539,986278;989088,989801;992511,993370;1010723,1011118;1024866,1025486;1032666,1033118;1034453,1035479;1050156,1051189;1063382,1063970;1090143,1090564;1104091,1105002;1115866,1116480;1135117,1135602;1138098,1138711;1154001,1154299;1181962,1182273;1197356,1199254;1206098,1206660;1219466,1220537;1227027,1228215;1234660,1235756;1259834,1260701;1283666,1284976;1297917,1298827;1300150,1301783;1312337,1313286;1324249,1325135;1327095,1327735;1366917,1367795;1384279,1385041;1395261,1396202;1399066,1399742;1429305,1430067;1458581,1459163;1511801,1512254;1611640,1611963;1629491,1629983;1634472,1636021;1672382,1672989;1686053,1686925;1687782,1688421;1699608,1700131;1708478,1710021;1787685,1788615;1837124,1837667;1838898,1839673;1847517,1848047;1864324,1865015;1923291,1924008;1936943,1938131;1943014,1943686;1984324,1985699;2004072,2005589;2006749,2008441;2016995,2017422;2028111,2028933;2071556,2072782;2075137,2075809;2102608,2102892;2118995,2119428;2140582,2143137;2154072,2154989;2218195,2218847;2272692,2273254;2296201,2296718;2303175,2303692;2317305,2317731;2328414,2329008;2379246,2380066;2472246,2472654;2474717,2475183;2476308,2477066;2491943,2492247;2535408,2535944;2575827,2576931;2580060,2580602;2667614,2667969;2673117,2673512;2683556,2683970;2767698,2767918;2769078,2770544;2772756,2773260;2785505,2785828;2787685,2788815;2878446,2878899;2909582,2910189;2923723,2924157;2971337,2971667;3007279,3007918;3023311,3023705;3029117,3029422;3031582,3032099;3037782,3038150;3049182,3049680;3086814,3087305;3088349,3088757;3189324,3190022;3240685,3241351;3250588,3251730;3282104,3282557;3343092,3343641;3351233,3351770;3369608,3370157;3386537,3387054;3398795,3399228;3419001,3419635;3454278,3454963;3478511,3478731;3484966,3485505;3493789,3494401;3507260,3507744;3564608,3566032;3585930,3587228;3596461,3597228;3607814,3608350;3625130,3625692;3649872,3650376;3679434,3680338;3707879,3708415;3734652,3735319;3817627,3818086;3828221,3828570;3843317,3844054;3852334,3852845;3914459,3914957;3919034,3919531;3930769,3931860;3956750,3957409;3958993,3959925;3973306,3974688;3987943,3988331;4037685,4038156;4062788,4063505;4081136,4081505;4082252,4082757;4084305,4084635;4116272,4117396;4165427,4166279;4174601,4175015;4236783,4237139;4256169,4256577;4264356,4264789;4270492,4270970]; 

%%%%%% R1128E %%%%% ***
% Mostly depth electrodes. Very frequency epileptic events that are present
% in temporal grids.

info.R1128E.FR1.session(1).bsfilt.peak      = [60, 119.9, 172.1, 179.9, 239.8]; % Session 1 (z-thresh 1)
info.R1128E.FR1.session(1).bsfilt.halfbandw = [0.7, 0.5,  0.5,   0.7,   0.5]; % Session 1 (z-thresh 1)

info.R1128E.FR1.session(1).badchan.broken = {'RTRIGD10', 'RPHCD9'}; % one is all line noise, the other large deviations
info.R1128E.FR1.session(1).badchan.epileptic = {'RANTTS1x', 'RANTTS2x', 'RANTTS3x', 'RANTTS4x', ... % interictal events
    'RINFFS1x' ... % marked as bad by Kahana Lab
    'RINFPS1x', 'RINFPS3x', 'RINFPS5x', 'RINFPS7x', 'RSUPPS1x', 'RSUPPS3x', 'RSUPPS5x', 'RSUPPS7x'}; % weird naming convention; slinky; also occipital/parietal

info.R1128E.FR1.session(1).badsegment = [99207,99478;135550,135784;213726,214090;220313,221010;240744,241075;252563,252825;262689,263399;264985,265663;277002,277164;490763,491336;571506,572235;583916,584840;646804,647352;676159,676623;766217,767189;828860,829244;830359,831105;872631,873655;1018759,1019307;1299921,1300619;1807973,1808643;1815413,1815930;1819433,1819765;1831655,1833078;1868574,1869154;1982802,1983754;2159589,2160001;2285284,2285854;2372943,2373480;2440251,2440784;2595946,2596451;2608393,2609014;2665639,2666566;2675616,2676290;2760076,2760818;2965178,2966194]; 

%%%%%% R1156D %%%%%
% Different grids are differentially affected by reference noise. Will need
% to re-reference some channels separately from one another in order to
% find signal. 

% Bad grids are LAF, LIHG, LPF, RFLG, RFLG, ROFS, RPS, RTS
% OK grids that still need re-ref help are RFG, RIHG, RFPS; RFG1 should be
% thrown out.

%%%%%% R1149N %%%%% 
% Lots of reference noise and also antenna channels. Channel TT6 is buzzy. Occasional line noise
% in channels even after filtering out line spectra. Lots of line spectra artifacts.

info.R1149N.FR1.session(1).bsfilt.peak =      [60, 120, 136, 180, 196.5, 211.6, 219.9, 226.7, 240, 241.9, 257, 272, 280, 287.2, 300, 332.5, 340, 347.7, 359.9, 360.9, 362.8, 377.9, 380, 393, 400, 408.1, 420, 423.3, 425.7, 438.4, 440, 460, 471, 480.1, 486.1];
info.R1149N.FR1.session(1).bsfilt.halfbandw = [0.5, 0.6, 0.5, 1.1, 0.5, 0.5, 0.5, 0.5, 1.6, 0.5, 0.5, 0.5, 0.5, 0.5, 1.8, 0.5, 0.6, 0.5, 1.6, 0.5, 0.5, 0.5, 0.5, 0.5, 0.6, 0.5, 1.4, 0.5, 0.5, 0.5, 0.5, 0.9, 0.5, 1.5, 0.5];

info.R1149N.FR1.session(1).badchan.broken = {'ALEX*', 'AST2', 'G1', 'LF2', 'LF3'};

%%%%%% R1034D %%%%% ***
% Lots of spiky channels, particularly in Session 1. Lots of reference noise in Session 3, reref helps.
peaks = [60, 120, 180, 180.1, 240, 240.1, 172.3, 183.5, 200, 212];
bw    = [0.6, 0.5, 0.5, 0.5,  0.6, 0.5,   0.5,   0.5,   0.5, 0.5];

info.R1034D.FR1.session(1).bsfilt.peak = peaks;
info.R1034D.FR1.session(1).bsfilt.halfbandw = bw;
info.R1034D.FR1.session(2).bsfilt.peak = peaks;
info.R1034D.FR1.session(2).bsfilt.halfbandw = bw;
info.R1034D.FR1.session(3).bsfilt.peak = peaks;
info.R1034D.FR1.session(3).bsfilt.halfbandw = bw;

% Session 1 (z-thresh 1): [60, 120, 180.1, 183.5, 240]
% Session 1 (z-thresh 1): [0.6, 0.5, 0.5,  0.5,   0.6]
% Session 1 (manual):     [172.3, 212]
% Session 1 (manual):     [0.5,   0.5]
% Session 2 (z-thresh 1): [60, 120, 172.3, 180, 240.1]
% Session 2 (z-thresh 1): [0.5, 0.5, 0.5,  0.5, 0.5]
% Session 3 (z-thresh 1): [60, 120, 172.3, 180, 240]
% Session 3 (z-thresh 1): [0.6, 0.5, 0.5,  0.5, 0.5]
% Session 3 (manual):     [200]
% Session 3 (manual):     [0.5]

info.R1034D.FR1.session(1).badchan.broken = {'LFG1x', 'LFG16x', 'LFG24x', 'LFG32x', 'LFG8x', 'LIHG16x', 'LIHG24x', 'LIHG8x', 'LOFG12x', 'LOFG6x', 'LOTD12', 'LTS8x', 'RIHG16x', 'RIHG8x', ... % flat-line channels
    'LOTD7'}; % large voltage fluctuations
info.R1034D.FR1.session(2).badchan.broken = {'LFG1x', 'LFG16x', 'LFG24x', 'LFG32x', 'LFG8x', 'LIHG16x', 'LIHG24x', 'LIHG8x', 'LOFG12x', 'LOFG6x', 'LOTD12', 'LTS8x', 'RIHG16x', 'RIHG8x', ... % flat-line channels
    'LOTD7'}; % large voltage fluctuations
info.R1034D.FR1.session(3).badchan.broken = {'LFG1x', 'LFG16x', 'LFG24x', 'LFG32x', 'LFG8x', 'LIHG16x', 'LIHG24x', 'LIHG8x', 'LOFG12x', 'LOFG6x', 'LOTD12', 'LTS8x', 'RIHG16x', 'RIHG8x', ... % flat-line channels
    'LOTD7'}; % large voltage fluctuations

info.R1034D.FR1.session(1).badchan.epileptic = {'LIHG17x', ... % big fluctuations and small sharp oscillations
    'LIHG18x', ... % small sharp oscillations
    'LFG13x', 'LFG14x', 'LFG15x', 'LFG22x', 'LFG23x'}; % marked by Kahana
info.R1034D.FR1.session(2).badchan.epileptic = {'LIHG17x', ... % big fluctuations and small sharp oscillations
    'LIHG18x', ... % small sharp oscillations
    'LFG13x', 'LFG14x', 'LFG15x', 'LFG22x', 'LFG23x'}; % marked by Kahana
info.R1034D.FR1.session(3).badchan.epileptic = {'LIHG17x', ... % big fluctuations and small sharp oscillations
    'LIHG18x', ... % small sharp oscillations
    'LFG13x', 'LFG14x', 'LFG15x', 'LFG22x', 'LFG23x'}; % marked by Kahana

info.R1034D.FR1.session(1).badsegment = [76801,77572;93764,94659;102208,102963;161824,162333;166173,166941;208310,208857;220358,221472;330990,331360;362431,363606;364801,365654;371201,371950;383154,384353;403812,404492;668336,669120;712323,712858;722060,723055;765115,766006;858349,858909;911304,912126;915704,916527;934152,935017;1417355,1418204;1562986,1563576;1626014,1626535;1762697,1763300;1994383,1995283;2144001,2144363;2265601,2268402;2272607,2273451;2280740,2281627;2324272,2325357;2446530,2447116;2558091,2559627;2572438,2573874;2608886,2609494;2634981,2636251;2641696,2643693;2680362,2680874;2682126,2682944;2694091,2695192];
info.R1034D.FR1.session(2).badsegment = [84629,85886;129373,129967;401329,402049;414413,414986;502327,502931;520018,521365;683230,683717;690585,690999;917209,917584;1222814,1223813;1307549,1308574;1436543,1438259;1448379,1450724;1562560,1563193;1789871,1791494;1875795,1877283;1956555,1958400;2037820,2039184;2083841,2084014;2158444,2159593;2189266,2189886;2244031,2244659;2270043,2271193;2387911,2388609;2399484,2400115;2402982,2403479;2764020,2764660;2802869,2803882;2817291,2818120;2827149,2828800;2838059,2839499;2934685,2935299;2953382,2953860;3067240,3068847;3071147,3072817;3123254,3124058;3174120,3175580;3256558,3258791;3335795,3336731;3649988,3650776;3790382,3791202;3833601,3838892;3862046,3863202;3956795,3958054;3985833,3987098;4262401,4263519;4462872,4464067;4495866,4496925];
info.R1034D.FR1.session(3).badsegment = [306485,307734;376117,377389;405640,408253;570137,570622;571872,572312;572949,573454;574207,574686;606594,608000;953731,955641;1116479,1118195;1380465,1382060];

%%%%%% R1162N %%%%%
% Very clean, only occassional reference noise across channels. WRONG. I
% WAS WRONG. VERY SHITTY.
info.R1162N.FR1.session(1).badchan.broken = {'AST2'};

%%%%%% R1033D %%%%%
% Very unclean, lots of reference noise and wayward channels.
info.R1033D.FR1.session(1).badchan.broken = {'LFS8', 'LOTD12', 'LTS8', 'RATS8', 'RFS8', 'RID12', 'ROTD12', 'RPTS8', 'LTS6', 'LOTD9'};

%%%%%% R1167M %%%%% ***
% Lots of reference noise, reref helps. Some ambiguous spiky channels remain.

peaks = [60, 100.3, 120, 180, 219.2, 220.2, 221.8, 239.9, 100, 219.8, 220.8, 221.3, 240, 58.7, 59.3, 61.3, 80, 95.3, 140, 160.1, 199.9];
bw =    [0.5, 0.5,  0.5, 0.5, 0.5,   0.7,   0.5,   0.5,   0.6, 1,     0.5,   0.5,   0.5, 1,    1,    1,    1,  1,    1,   1,     1];
info.R1167M.FR1.session(1).bsfilt.peak = peaks;
info.R1167M.FR1.session(1).bsfilt.halfbandw = bw;

info.R1167M.FR1.session(2).bsfilt.peak = peaks;
info.R1167M.FR1.session(2).bsfilt.halfbandw = bw;

% Session 1 (z-thresh 1.75): [60, 100.3, 120, 180, 219.2, 220.2, 221.8, 239.9]
% Session 1 (z-thresh 1.75): [0.5, 0.5, 0.5, 0.5, 0.5, 0.7, 0.5, 0.5]
% Session 2 (z-thresh 1.75): [60, 100, 120, 180, 219.8, 220.8, 221.3, 240]
% Session 2 (z-thresh 1.75): [0.5, 0.6, 0.5, 0.5, 1, 0.5, 0.5, 0.5]
% Session 2 (manual):        [58.7, 59.3, 61.3, 80, 95.3, 140, 160.1, 199.9]
% Session 2 (manual):        [1, 1, 1, 1, 1, 1, 1, 1]

info.R1167M.FR1.session(1).badchan.broken = {'LP7x', ... % sinusoidal noise
    'LP8x'}; % spiky and large fluctuations
info.R1167M.FR1.session(2).badchan.broken = {'LP7x', ... % sinusoidal noise
    'LP8x'}; % spiky and large fluctuations

info.R1167M.FR1.session(1).badchan.epileptic = {'LP1x', 'LAT8x', 'LAT11x', 'LAT12x', 'LAT13x', 'LAT16'};
info.R1167M.FR1.session(2).badchan.epileptic = {'LP1x', 'LAT8x', 'LAT11x', 'LAT12x', 'LAT13x', 'LAT16'};

info.R1167M.FR1.session(1).badsegment = [37142,37344;89033,89429;163129,163469;259250,259900;407368,408122;410755,411081;530291,530437;554512,555489;774886,776472;827947,828821;883069,883578;907727,908612;921239,921429;1082561,1083227;1083681,1085205;1223384,1224281;1345533,1346147;1430762,1431691;1496380,1497558;1607234,1607799;1651123,1652462;1707308,1708777;1866573,1867287;1870621,1871562;1873577,1874239;2037952,2038078];
info.R1167M.FR1.session(2).badsegment = [60001,60466;165698,166300;194025,194836;196835,197284;262307,263038;393231,394324;409884,410917;434073,435727;463097,464000;497222,498260;508763,511304;535722,536436;543769,544591;777198,778018;1038105,1038546;1139014,1140845;1164066,1164917;1215904,1217661;1303928,1304374;1348001,1348978;1399379,1400925;1447166,1447384;1654424,1654977;1704279,1706082;1821823,1822985];

%%%%%% R1175N %%%%%
% Lots of reference noise, reref helps some, but sinusoidal channels
% remain.
info.R1175N.FR1.session(1).badchan.broken = {'RAT8', 'RPST2', 'RPST3', 'RPST4', 'RPT6'};

%%%%%% R1154D %%%%%
% Very noisy, even after reref. First 230 seconds of Session 3 are
% corrupted.
info.R1154D.FR1.session(1).badchan.broken = {'LOTD*', 'LTCG23'};
info.R1154D.FR1.session(2).badchan.broken = {'LOTD*', 'LTCG23'};
info.R1154D.FR1.session(3).badchan.broken = {'LOTD*', 'LTCG23'};

%%%%%% R1068J %%%%%
% Looks funny, but relatively clean. Reference noise in grids RPT and RF go
% haywire by themselves, might need to re-reference individually.
info.R1068J.FR1.session(1).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};
info.R1068J.FR1.session(2).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};
info.R1068J.FR1.session(3).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};

%%%%%% R1159P %%%%%
% REALLY REALLY SHITTY AND I CAN'T EVEN RIGHT NOW

%%%%%% R1080E %%%%% 
% Lots of noise (spikes) across channels, reref helps. 'L5D10', 'R10D7',
% and 'RSFS4' go wonky in the second session only.
info.R1080E.FR1.session(2).badchan.broken = {'L9D7', 'R10D1', 'R12D7', 'RLFS7', 'L5D10', 'R10D7', 'RSFS4'};
info.R1080E.FR1.session(2).badchan.broken = {'L9D7', 'R10D1', 'R12D7', 'RLFS7', 'L5D10', 'R10D7', 'RSFS4'};

%%%%%% R1142N %%%%% ***
% Looks very, very clean.
info.R1142N.FR1.session(1).badchan.broken = {'ALT6'};

%%%%%% R1059J %%%%% ***
% Relatively clean, though many channels occasionally break. Still need to
% track down all of the breaking channels.
info.R1059J.FR1.session(1).badchan.broken = {'LDC*', 'LFB3'};
info.R1059J.FR1.session(2).badchan.broken = {'LDC*', 'LFB3'};

%%%%%% R1135E %%%%%
% Frequent interictal events, and lots of channels show bursts of 20Hz
% activity. RSUPPS grid goes bad in Session 3. Session 3 has lots of
% reference noise.
info.R1135E.FR1.session(1).badchan.broken = {'LHCD9', 'RPHCD1', 'RPHCD9', 'RSUPPS*'};
info.R1135E.FR1.session(2).badchan.broken = {'LHCD9', 'RPHCD1', 'RPHCD9', 'RSUPPS*'};
info.R1135E.FR1.session(3).badchan.broken = {'LHCD9', 'RPHCD1', 'RPHCD9', 'RSUPPS*'};
info.R1135E.FR1.session(4).badchan.broken = {'LHCD9', 'RPHCD1', 'RPHCD9', 'RSUPPS*'};

%%%%%% R1147P %%%%%
% Dominated by reference noise, and different across grids. In session 2,
% LGR grid looks clean.

%%%%%% R1020J %%%%% ***
% Relatively clean, some reference noise (and different across grids).
info.R1020J.FR1.session(1).badchan.broken = {'RSTB5', 'RAH7', 'RPH7'};

%%%%%% R1045E %%%%% ***
% Looks very clean.
info.R1045E.FR1.session(1).badchan.broken = {'RPHD1', 'RPHD7', 'RPTS7', 'LIFS10', 'LPHD9'};

end