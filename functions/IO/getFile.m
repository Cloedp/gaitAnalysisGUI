function [ c ] = getFile( c )
%GETFILE Summary of this function goes here
%   Detailed explanation goes here
    c = getFileGUI(c);
%     c.info.name = 'Benjamin';
%     c.info.height = 1756;
%     c.info.mass = 50.1;
%     c.info.age = 11.5;
%     c.info.sexe = 0;
%     c.info.aide = 2;
%     c.info.aideStr = 'Canne (2)';
%     c.info.note = 'Yo!';
%     c.file.path = '/home/pariterre/Programmation/c3dToExcel/data/Annie/';
%     c.file.names = {'CTL-enf-008_marche_09.c3d' 'CTL-enf-008_marche_10.c3d' 'CTL-enf-011_marche_08.c3d' 'CTL-enf-011_marche_10.c3d'};
%     c.file.savepath = '/home/pariterre/Programmation/c3dToExcel/result/coucou.csv';
%     c.staticfile.names = {'CTL-enf-008_marche_09.c3d'};
%     c.staticfile.path = '/home/pariterre/Programmation/c3dToExcel/data/Annie/';
%     c.eei.fc_repos = 80.4;
%     c.eei.fc_marche = 172.52;
%     c.eei.v_marche = 37.58;

    % S'assurer qu'on veut analyser quelque chose
    if isempty(c)
        return;
    end
    
    % Ouvrir et découper les données
    [dataAll, c.file, c.c3d] = openAndParseC3Ds(c.file);
    [dataStatic, c.staticfile, c3dStatic] = openAndParseC3Ds(c.staticfile);
    kinToKeep.Left = 1:length(dataStatic.Left);
    kinToKeep.Right = 1:length(dataStatic.Right);
    dynToKeep.Left = [];
    dynToKeep.Right = [];
    c.staticfile.data = meanAllResults(dataStatic, kinToKeep, dynToKeep, c.info);
    c.staticfile.c3d = c3dStatic;
    
    % Faire choisir à l'utilisateur les essais à conserver
    [kinToKeep, dynToKeep] = selectFilesToUse(dataAll);
%     kinToKeep.Left = [1 2 7 8];
%     kinToKeep.Right = [5 6 7 8];
%     dynToKeep.Left = [1 7];
%     dynToKeep.Right = [7]; %#ok<NBRAK>
    
    
    % Élager les données selon ce qui a été choisi
    dataFinal = meanAllResults(dataAll, kinToKeep, dynToKeep, c.info);
    
    % Mettre les données dans la variable de sortie
    c.data = dataFinal;
end

function dataFinal = meanAllResults(dataAll, kinToKeep, dynToKeep, info)

    sides = fieldnames(kinToKeep);
    for iS = 1:length(sides)
        s = sides{iS};
        dataKinAll = dataAll.(s)(kinToKeep.(s));
        dataDynAll = dataAll.(s)(dynToKeep.(s));

        % Faire le moyennage des données
        angle_fnames = fieldnames(dataAll.(s)(1).angle);
        marker_fnames = fieldnames(dataAll.(s)(1).markers);
        moment_fnames = fieldnames(dataAll.(s)(1).moment);
        power_fnames = fieldnames(dataAll.(s)(1).power);
        CentreOfMass = fieldnames(dataAll.(s)(1).CentreOfMass);
        for j = 1:length(angle_fnames)
            for i = 1:length(dataKinAll)
                kin_angle.(angle_fnames{j})(:,:,i) = dataKinAll(i).angle.(angle_fnames{j});
            end
            kin_angle.(angle_fnames{j}) = mean(kin_angle.(angle_fnames{j}),3);
        end
        for j = 1:length(marker_fnames)
            for i = 1:length(dataKinAll)
                d = dataKinAll(i).markers.(marker_fnames{j});
                % S'assurer que la marche est vers l'avant (tourne autour de z)
                if d(end,2) - d(1,2) < 0
                    d(:,[1 2]) = -d(:,[1 2]);
                end
                % Partir en fct de l'extrême min pour lat,  0 pour frontal et ne rien changer en hauteur 
                kin_markers.(marker_fnames{j})(:,:,i) = d - [repmat([min(d(:,1)), d(1,2)], [size(d,1), 1]), zeros(size(d(:,3)))]; 
            end
            kin_markers.(marker_fnames{j}) = mean(kin_markers.(marker_fnames{j}),3);
        end
        for j = 1:length(CentreOfMass)
            for i = 1:length(dataKinAll)
                com_info.(CentreOfMass{j})(:,:,i) = dataKinAll(i).CentreOfMass.(CentreOfMass{j});
            end
            com_info.(CentreOfMass{j}) = mean(com_info.(CentreOfMass{j}),3);
        end
        for j = 1:length(moment_fnames)
            for i = 1:length(dataKinAll)
                kin_moment.(moment_fnames{j})(:,:,i) = dataKinAll(i).moment.(moment_fnames{j});
            end
            kin_moment.(moment_fnames{j}) = mean(kin_moment.(moment_fnames{j}), 3);
        end
        for j = 1:length(power_fnames)
            for i = 1:length(dataKinAll)
                kin_power.(power_fnames{j})(:,:,i) = dataKinAll(i).power.(power_fnames{j});
            end
            kin_power.(power_fnames{j}) = mean(kin_power.(power_fnames{j}),3);
        end
        for pf = 1:length(dataAll.(s)(i).forceplate)
            fp_fnames = {'Fx' 'Fy' 'Fz' 'Mx' 'My' 'Mz'};
            for j = 1:length(fp_fnames)
                dyn_forceplate = [];
                for i = 1:length(dataDynAll)
                    comp_names = fieldnames(dataDynAll(i).forceplate(pf).channels);
                    dyn_forceplate(pf).channels.(fp_fnames{j})(:,:,i) = dataDynAll(i).forceplate(pf).channels.(comp_names{j}); %#ok<AGROW>
                end
                if ~isempty(dyn_forceplate)
                    dyn_forceplate(pf).channels.(fp_fnames{j}) = mean(dyn_forceplate(pf).channels.(fp_fnames{j}),3); %#ok<AGROW>
                end
            end
        end
        stampsToDo = {'Left_Foot_Off', setdiff( {'Left_Foot_Strike', 'Right_Foot_Strike'}, [s '_Foot_Strike']), 'Right_Foot_Off'};
        stampsToDo(2) = stampsToDo{2};
        for j=1:length(stampsToDo)
            for i = 1:length(dataKinAll)
                stamps.(stampsToDo{j}).frameStamp(i) = dataKinAll(i).stamps.(stampsToDo{j}).frameStamp;
            end
            stamps.(stampsToDo{j}).frameStamp = round(mean(stamps.(stampsToDo{j}).frameStamp));
        end
        tempsCycle = mean([dataKinAll(:).tempsCycle]);

        % Le cas de Left_Foot_Strike est spécial car 2 valeurs (1 et 100)
        stamps.([s '_Foot_Strike']).frameStamp = [1 100]; 
        stamps = extractStamps(stamps, 100);

        % Assembler les données moyennées
        dataFinalTp.info = info; % Prendre les infos demandé à l'ouverture
        dataFinalTp.angleInfos = dataAll.Left(1).angleInfos; 
        dataFinalTp.angle = kin_angle;
        dataFinalTp.markers = kin_markers;
        dataFinalTp.CentreOfMass = com_info;
        dataFinalTp.moment = kin_moment;
        dataFinalTp.power = kin_power;
        dataFinalTp.forceplate = dyn_forceplate;
        dataFinalTp.stamps = stamps;
        dataFinalTp.tempsCycle = tempsCycle;

        % Inutile maintenant, mais j'ai besoin des stamps quand même!
        dataFinalTp = computePourcentCycleMarche(dataFinalTp);

        % Rearranger les données pour extraire certains paramètres
        dataFinalTp.eventData(i) = rearangeIntoEvents(dataFinalTp, ...
                {'Left_Foot_Off' 'Right_Foot_Off' 'Left_Foot_Strike' 'Right_Foot_Strike'}, ...
                {'LHipAngles' 'RHipAngles' 'LKneeAngles' 'RKneeAngles' 'LAnkleAngles' 'RAnkleAngles'});
        dataFinal.(s) = dataFinalTp;
        clear dataFinalTp
    end
end

function [dataAll, file, c3d] = openAndParseC3Ds(file)
% Parse and open
    cmpLeft = 1;
    cmpRight = 1;
    for i=1:length(file.names)
        [~,file.names{i},file.ext{i}] = fileparts(file.names{i});
        file.fullpath{i} = [file.path file.names{i} file.ext{i}];
        
        % Ouvrir un fichier BTK
        c3d(i) = btkReadAcquisition(file.fullpath{i}); %#ok<AGROW>
        
        data = extractDataFromC3D(c3d(i));
        
        % Reclasser les données (faire qu'un essai soit un "fichier")
        for j = 1:length(data.norm.Left)
            data.norm.Left(j).filename = sprintf('%s_CôtéGauche_%d', file.names{i}, j);
            % Calcul spécial pour le centre de masse, calculer tout de suite le médiolatéral 
            data.norm.Left(j).CentreOfMass.ml = abs(max(data.norm.Left(j).markers.CentreOfMass(:,1)) - min(data.norm.Left(j).markers.CentreOfMass(:,1)));

            dataAll.Left(cmpLeft) = data.norm.Left(j); 
            cmpLeft = cmpLeft+1;
        end
        for j = 1:length(data.norm.Right)
            data.norm.Right(j).filename = sprintf('%s_CôtéDroit_%d', file.names{i}, j);
            % Calcul spécial pour le centre de masse, calculer tout de suite le médiolatéral 
            data.norm.Right(j).CentreOfMass.ml = abs(max(data.norm.Right(j).markers.CentreOfMass(:,1)) - min(data.norm.Right(j).markers.CentreOfMass(:,1)));
            dataAll.Right(cmpRight) = data.norm.Right(j); 
            
            cmpRight = cmpRight+1;
        end
    end
    % Prendre les infos du derniers (ils sont sensés être tous les mêmes)
    dataAll.Left(1).angleInfos = data.angleInfos;
    dataAll.Right(1).angleInfos = data.angleInfos;
end