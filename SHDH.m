function [G, F, B] = SHDH(X,y,B,gmap,Fmap,Hmap,tol,maxItr,debug)

% ---------- Argument defaults ----------
if ~exist('debug','var') || isempty(debug)
    debug=1;
end
if ~exist('tol','var') || isempty(tol)
    tol=1e-5;
end
if ~exist('maxItr','var') || isempty(maxItr)
    maxItr=1000;
end
nu = Fmap.nu;
delta = 1/nu;
% ---------- End ----------

% label matrix N x c
if isvector(y) 
    Y = sparse(1:length(y), double(y), 1); Y = full(Y);
else
    Y = y;
end


% G-step
switch gmap.loss
    case 'L2'
        [Wg, ~, ~] = RRC(B, Y, gmap.lambda); % (Z'*Z + gmap.lambda*eye(nbits))\Z'*Y;
    case 'Hinge'
        svm_option = ['-q -s 4 -c ', num2str(1/gmap.lambda)];
        model = train(double(y),sparse(B),svm_option);
        Wg = model.w';
end
G.W = Wg;

% F-step

[WF, ~, ~] = RRC(X, B, Fmap.lambda);

F.W = WF; F.nu = nu;
beta = Hmap.beta;
H=Hmap.graph;
i = 0;

% maxItrb=5;
% OrigB=[];
while i < maxItr    
    i=i+1;  
    
    if debug,fprintf('Iteration  %03d: ',i);end
    
    % B-step
  
        XF = X*WF;
        Q = nu*XF + Y*Wg';
        B = zeros(size(B));          
        for time = 1:5           
           Z0 = B;
            for k = 1 : size(B,2)
                Zk = B; Zk(:,k) = [];
                b_k=B(:,k);
                Wkk = Wg(k,:); Wk = Wg; Wk(k,:) = []; 
                t1=beta*H*b_k +Q(:,k) -  Zk*Wk*Wkk';
                %t1=Q(:,k) -  Zk*Wk*Wkk';
                temp=func_C(t1,b_k);
                B(:,k) = sign(temp);
            end

            if norm(B-Z0,'fro') < 1e-6 * norm(Z0,'fro')
                break
            end
        end
%     switch gmap.loss
%         case 'L2'
%             Q = nu*XF + Y*Wg';
%             
%             B = zeros(size(B));          
%             for time = 1:10           
%                Z0 = B;
%                 for k = 1 : size(B,2)
%                     Zk = B; Zk(:,k) = [];
%                     Wkk = Wg(k,:); Wk = Wg; Wk(k,:) = [];                    
%                     B(:,k) = sign(Q(:,k) -  Zk*Wk*Wkk');
%                 end
%                 
%                 if norm(B-Z0,'fro') < 1e-6 * norm(Z0,'fro')
%                     break
%                 end
%             end
%         case 'Hinge' 
%             
%             for ix_z = 1 : size(B,1)
%                 w_ix_z = bsxfun(@minus, Wg(:,y(ix_z)), Wg);
%                 B(ix_z,:) = sign(2*nu*XF(ix_z,:) + delta*sum(w_ix_z,2)');
%             end
           %             Q = nu*XF + Y*Wg';
%             

    %end

    
    % G-step
    switch gmap.loss
    case 'L2'
        [Wg, ~, ~] = RRC(B, Y, gmap.lambda); % (Z'*Z + gmap.lambda*eye(nbits))\Z'*Y;
    case 'Hinge'        
        model = train(double(y),sparse(B),svm_option);
        Wg = model.w';
    end
    G.W = Wg;
    
    % F-step 
    WF0 = WF;
    
    [WF, ~, ~] = RRC(X, B, Fmap.lambda);
   
    F.W = WF; F.nu = nu;
    
    
    
    
    bias = nu*norm(B-X*WF,'fro');
    I=eye(size(H,1));
    L=I-H;
    bias2 = beta*trace(B'*L*B);
    bias3 = norm(Y-B*Wg,'fro');
    if debug, fprintf('bias3 = %g, bias1=%g, bias2=%g\n',bias3,bias,bias2); 
    end
    
    if bias < tol*norm(B,'fro')
            break;
    end 
    
    
    if norm(WF-WF0,'fro') < tol * norm(WF0)
        break;nil
    end
    
    
end
