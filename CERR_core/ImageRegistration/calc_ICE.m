function dist3M = calc_ICE(scan1PlanC,scan2PlanC,strNum1,scanNum2,varargin)
% Returns inverse consistency error in registration
% AI 4/25/17
% ============================================================================================
% Inputs
% scan1PlanC  : CERR archive with base plan
% scan2planC  : CERR archive with moving plan
% strNum1     : Structure no. on base plan
% strNum2     : Corresponding structure no. on moving plan
% --Optional --
% varargin{1} : algorithm
% varargin{2} : baseMask3M 
% varargin{3} : movMask3M
% varargin{4} : boneThreshold
% See register_scans for details
% 
% --Example--
% [scan1PlanC, scan2PlanC] = register_scans(scan1PlanC, scan2PlanC, scan1Num, scan2Num, ...
%                            'BSPLINE PLASTIMATCH', [], [], []);             %Fwd transform
% dist3M = calc_ICE(scan1PlanC,scan2PlanC,strNum1,strNum2);                  %ICE measure
% =============================================================================================

%Define defaults for optional inputs
minargs = 4;
maxargs = 8;
narginchk(minargs,maxargs)
nVarargs = nargin - minargs;
algorithm = 'BSPLINE PLASTIMATCH';
baseMask3M = [];
movMask3M = [];
boneThreshold = [];
optC = {algorithm, baseMask3M, movMask3M, boneThreshold};
[optC{1:nVarargs}] = varargin{:};
[algorithm,baseMask3M,movMask3M,boneThreshold] = optC{:};

%Get scans associated with stuctures
scanNum1 = getStructureAssociatedScan(strNum1,scan1PlanC);
% scanNum2 = getStructureAssociatedScan(strNum2,scan2PlanC);

%Get structure coordinates on scan1
indexS = scan1PlanC{end};
rasterSegments = getRasterSegments(strNum1,scan1PlanC);
[mask3M, uniqueSlices] = rasterToMask(rasterSegments, scanNum1, scan1PlanC);
[x1V, y1V, z1V] = getScanXYZVals(scan1PlanC{indexS.scan}(scanNum1));
[xM, yM] = meshgrid(x1V, y1V);
pts1M = [];
for slcNum = 1:length(uniqueSlices)
    slcmaskM = mask3M(:,:,slcNum);
    numPts = sum(slcmaskM(:));
    pts1M = [pts1M; xM(slcmaskM(:)), yM(slcmaskM(:)), ...
        z1V(uniqueSlices(slcNum))*ones(numPts,1)];
end


%Get deformation index for fwd transformation (scan2 to scan1)
scan1UID = scan1PlanC{indexS.scan}(scanNum1).scanUID;
scan2UID = scan2PlanC{indexS.scan}(scanNum2).scanUID;
deformS = scan1PlanC{indexS.deform};
deform1Idx  = getDeformIdx(scan1UID,scan2UID,deformS);
deform1S = scan1PlanC{indexS.deform}(deform1Idx);

%Get registered coordinates on scan2 (forward transform)
[x2DeformV, y2DeformV, z2DeformV] = getDeformationAt(deform1S,scan2PlanC,scanNum2,scan1PlanC,scanNum1,pts1M);
pts2M = pts1M + [x2DeformV, y2DeformV, z2DeformV];

%Get deformation index (inverse transform)
deform2Idx  = getDeformIdx(scan2UID,scan1UID,deformS);
if isempty(deform2Idx)
    %Register base to moving scan (inverse transform)
    [scan2PlanC, scan1PlanC] = register_scans(scan2PlanC, scan1PlanC, scanNum2, scanNum1, ...
        algorithm, baseMask3M, movMask3M, boneThreshold);
    deform2Idx = length(scan1PlanC{indexS.deform});
end


%Get registered coordinates on scan1 (inverse transform)
deform2S = scan1PlanC{indexS.deform}(deform2Idx);
[x1DeformV,y1DeformV,z1DeformV] = getDeformationAt(deform2S,scan1PlanC,scanNum1,scan2PlanC,scanNum2,pts2M);
mappedPts1M = pts2M + [x1DeformV,y1DeformV,z1DeformV];

%Compute distance
distV = sqrt(sum((pts1M - mappedPts1M).^2,2));
[rows,cols,slcs] = size(getScanArray(scanNum1,scan1PlanC));
dist3M = zeros(rows,cols,slcs);
start = 0;
for slcNum = 1:length(uniqueSlices)
    slcmaskM = mask3M(:,:,slcNum);
    distMaskV = double(slcmaskM(:));
    numPts = start + sum(distMaskV);
    dist = distV(start+1:numPts);
    distMaskV(distMaskV~=0)= dist;
    dist3M(:,:,uniqueSlices(slcNum)) = reshape(distMaskV,rows,cols); 
    start = numPts;
end


% --------------------------------------------------------------------------------
    function deformIdx  = getDeformIdx(scan1UID,scan2UID,deformS)
        
        baseMapV = strcmp(scan1UID,{deformS.baseScanUID});
        movMapV = strcmp(scan2UID,{deformS.movScanUID});
        deformIdx = find(baseMapV & movMapV,1,'last');
        
        
    end

end