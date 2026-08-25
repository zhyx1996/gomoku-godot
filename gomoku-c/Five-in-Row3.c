#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define SIZE 15
#define CHARSIZE 2

void pvp(void);
void pve(void);
int getchess(int *x,int *y);
void AIgetchess(int *x,int *y,int targetchess);
//用于记录递归次数
int countdigui;
//用于记录棋型
struct lnode{
	int huo;
	int number;
	int n;
	struct lnode *next;
};

void gettype(struct lnode *type[SIZE][SIZE],int chess);
void analysedata(int number11,int number21,int number12,int number22,int skip1,int havespace1,int skip2,int havespace2,int x,int y,struct lnode *type[SIZE][SIZE]);
void getscore(int *temp,int target_score[SIZE][SIZE],int other_score[SIZE][SIZE],struct lnode *target_type[SIZE][SIZE],struct lnode *other_type[SIZE][SIZE]);
void writelnode(int huo,int number,int n,int x,int y,struct lnode *type[SIZE][SIZE]);
int playerchess,computerchess;

void clear_mydata(int target_score[SIZE][SIZE],int other_score[SIZE][SIZE],struct lnode *target_type[SIZE][SIZE],struct lnode *other_type[SIZE][SIZE]);

void initRecordBoard(void);
void recordtoDisplayArray(void);
void displayBoard(void);
int win(int x,int y);
int isfull(void);
//棋盘使用Unicode画的，一个符号占两个char，所以要*2，+1是为了末尾的'\0'
char aInitDisplayBoardArray[SIZE][SIZE*CHARSIZE+1] = 
{
		"┏┯┯┯┯┯┯┯┯┯┯┯┯┯┓",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┠┼┼┼┼┼┼┼┼┼┼┼┼┼┨",
		"┗┷┷┷┷┷┷┷┷┷┷┷┷┷┛"

	
};
//此数组用于显示
char aDisplayBoardArray[SIZE][SIZE*CHARSIZE+1];
//此数组用于算法计算使用
int aRecordBoard[SIZE][SIZE];//
char play1Pic[]="●";
char play2Pic[]="◎";

//主函数，用于选择模式
void main(){
	int c,d,mode=0;
	while(1){
		system("clear");
		printf("\t   ========Welcome to Five-in-Row Game========\n");
		printf("\t\t1: Player vs. player\n");
		printf("\t\t2: Player vs. Computer\n");
		printf("\t\t3: Quit\n");
		while((c=getchar())==' '||c=='\t');
		while((d=getchar())==' '||d=='\t');
		if(d!='\n' && d!=EOF){
			printf("选个模式而已，就不要难为我了吧...大人再来一遍吧Orz...");
			while((c=getchar())!='\n' && c!=EOF);
			while((c=getchar())!='\n' && c!=EOF);
			continue;
		}
		switch(c){
		case '1':
			mode=1;
			break;
		case '2':
			mode=2;
			break;
		case '3':
			exit(0);
			break;
		default:
		printf("选个模式而已，就不要难为我了吧...大人再来一遍吧Orz...");
		while((c=getchar())!='\n' && c!=EOF);

		break;
		}
		if(mode==1)
			pvp();
		else if(mode==2)
			pve();
		else
			continue;
	
	}
}

//人人对战
void pvp(){
	int error;
	int c,d,x,y;
	initRecordBoard();
	recordtoDisplayArray();
	displayBoard();
	while(1){
		printf("Player1's turn: ");
		while(1){
			if((error=getchess(&x,&y))==1)
				printf("Please input again: ");
			else if(!error && aRecordBoard[x][y]!=0){
				printf("警告：已落子的地方禁止落子！请不要篡改棋局QAQ\n");
				printf("Please input again: ");
			}
			else
				break;
		}

		if(!error){
			aRecordBoard[x][y]=1;
			recordtoDisplayArray();
			displayBoard();
			if(isfull()){
				printf("\n\t\tDraw!：）\n\n");
				printf("\t\t1: Return\n");
				printf("\t\t2: Quit\n");
				while((c=getchar())==' ');
				if((d=getchar())!='\n' && d!=EOF){
					while((c=getchar())!='\n' && c!=EOF);
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				switch(c){
				case '1':
					return;
				case '2':
					exit(0);
					break;
				default:
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				
			}
		
			else if(win(x,y)){
				printf("\n\t\tCongratulation: Player1 Win!：）\n\n");
				printf("\t\t1: Return\n");
				printf("\t\t2: Quit\n");
				while((c=getchar())==' ');
				if((d=getchar())!='\n' && d!=EOF){
					while((c=getchar())!='\n' && c!=EOF);
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				switch(c){
				case '1':
					return;
				case '2':
					exit(0);
					break;
				default:
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				
			}
		}else
			return;

		printf("Player2's turn: ");
		while(1){
			if((error=getchess(&x,&y))==1)
			printf("Please input again: ");
			else if(!error && aRecordBoard[x][y]!=0){
				printf("警告：已落子的地方禁止落子！请不要篡改棋局QAQ\n");
				printf("Please input again: ");
			}
			else
				break;
		}

		if(!error){
			aRecordBoard[x][y]=2;
			recordtoDisplayArray();
			displayBoard();
			if(isfull()){
				printf("\n\t\tDraw!：）\n\n");
				printf("\t\t1: Return\n");
				printf("\t\t2: Quit\n");
				while((c=getchar())==' ');
				if((d=getchar())!='\n' && d!=EOF){
					while((c=getchar())!='\n' && c!=EOF);
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				switch(c){
				case '1':
					return;
				case '2':
					exit(0);
					break;
				default:
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
			}
			else if(win(x,y)){
				printf("\n\t\tCongratulation: Player2 Win!：）\n\n");
				printf("\t\t1: Return\n");
				printf("\t\t2: Quit\n");
				while((c=getchar())==' ');
				if((d=getchar())!='\n' && d!=EOF){
					while((c=getchar())!='\n' && c!=EOF);
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				switch(c){
				case '1':
					return;
				case '2':
					exit(0);
					break;
				default:
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					break;
				}
				
			}
		}else
			return;
	}
}	

//人机对战
void pve(){
	int error,mode;
	int c,d,x,y;
	while(1){
		system("clear");
		printf("\t   ========Welcome to Five-in-Row Game========\n");
		printf("\t\t1: You First\n");
		printf("\t\t2: Computer First\n");
		while((c=getchar())==' ');
		if((d=getchar())!='\n' && d!=EOF){
		while((c=getchar())!='\n' && c!=EOF);
		printf("选个模式而已，就不要难为我了吧...大人再来一遍吧Orz...");
		while((c=getchar())!='\n' && c!=EOF);
		continue;
		}
		switch(c){
		case '1':
			mode=1;
			break;
		case '2':
			mode=2;
			break;
		default:
		printf("选个模式而已，就不要难为我了吧...大人再来一遍吧Orz...");
		while((c=getchar())!='\n' && c!=EOF);
		continue;
		}
	break;
	}		


	initRecordBoard();
	recordtoDisplayArray();
	displayBoard();
	if(mode==2){
		computerchess=1;
		playerchess=2;
		x=7,y=7;
		aRecordBoard[x][y]=computerchess;
		recordtoDisplayArray();
		displayBoard();
		printf("Computer place chess at (%c,%d).\n",'A'+y,15-x);
	}else{
		computerchess=2;
		playerchess=1;
	}
	
	
	while(1){
		printf("Your turn: ");
		while(1){
			if((error=getchess(&x,&y))==1)
				printf("Please input again: \n");
			else if(!error && aRecordBoard[x][y]!=0){
				printf("警告：已落子的地方禁止落子！请不要篡改棋局QAQ\n");
				printf("Please input again: ");
			}
			else
				break;
		}

		if(!error){
			aRecordBoard[x][y]=playerchess;
			recordtoDisplayArray();
			displayBoard();
			if(isfull()){
				printf("\n\t\tDraw!：）\n\n");
				printf("\t\t1: Return\n");
				printf("\t\t2: Quit\n");
				while((c=getchar())==' ');
				if((d=getchar())!='\n' && d!=EOF){
					while((c=getchar())!='\n' && c!=EOF);
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				switch(c){
				case '1':
					return;
				case '2':
					exit(0);
					break;
				default:
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				
			}
		
			else if(win(x,y)){
				printf("\n\t\tYou Win!：）\n\n");
				printf("\t\t1: Return\n");
				printf("\t\t2: Quit\n");
				while((c=getchar())==' ');
				if((d=getchar())!='\n' && d!=EOF){
					while((c=getchar())!='\n' && c!=EOF);
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				switch(c){
				case '1':
					return;
				case '2':
					exit(0);
					break;
				default:
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				
			}
		}else
			return;
		countdigui=0;
		AIgetchess(&x,&y,computerchess);
		aRecordBoard[x][y]=computerchess;
		recordtoDisplayArray();
		displayBoard();
		printf("Computer place chess at (%c,%d).\n",'A'+y,15-x);
		if(isfull()){
				printf("\n\t\tDraw!：）\n\n");
				printf("\t\t1: Return\n");
				printf("\t\t2: Quit\n");
				while((c=getchar())==' ');
				if((d=getchar())!='\n' && d!=EOF){
					while((c=getchar())!='\n' && c!=EOF);
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				switch(c){
				case '1':
					return;
				case '2':
					exit(0);
					break;
				default:
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				
			}
		
		else if(win(x,y)){
				printf("\n\t\tYou Lose... ：（\n\n");
				printf("\t\t1: Return\n");
				printf("\t\t2: Quit\n");
				while((c=getchar())==' ');
				if((d=getchar())!='\n' && d!=EOF){
					while((c=getchar())!='\n' && c!=EOF);
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				switch(c){
				case '1':
					return;
				case '2':
					exit(0);
					break;
				default:
					printf("下都下完了，就不要难为我了吧...小的给您返回了Orz...");
					while((c=getchar())!='\n' && c!=EOF);
					return;
				}
				
		}
	}
}

//AI选择落子点
void AIgetchess(int *x,int *y,int targetchess){
//用于记录分数
	int target_score[SIZE][SIZE];
	int other_score[SIZE][SIZE];
//用于记录棋型
	struct lnode *target_type[SIZE][SIZE];
	struct lnode *other_type[SIZE][SIZE];

	int otherchess=(targetchess==1)?2:1;
	int i,j;
	int max=0;
//用来记录target的非制胜空点的分数
	int temp=0;


//通过双重循环，初始化四个数组
	for(i=0;i<SIZE;i++)
	for(j=0;j<SIZE;j++){
		target_score[i][j]=0;
		other_score[i][j]=0;
		target_type[i][j]=NULL;
		other_type[i][j]=NULL;
	}




	gettype(target_type,targetchess);
	gettype(other_type,otherchess);
	getscore(&temp,target_score,other_score,target_type,other_type);
	for(i=0;i<SIZE;i++)
	for(j=0;j<SIZE;j++)
		if(aRecordBoard[i][j]==0){
			if(target_score[i][j]>1000){
				if((((other_score[i][j]+temp)>target_score[i][j])?(other_score[i][j]+temp):target_score[i][j])>max){
					max=((other_score[i][j]+temp)>target_score[i][j])?(other_score[i][j]+temp):target_score[i][j];
					*x=i;*y=j;

				}
			}
			else if((other_score[i][j]+temp)>1000){
				if((other_score[i][j]+temp)>max){
					max=(other_score[i][j]+temp);
					*x=i;*y=j;
				}
			}
			else{
				if(other_score[i][j]+target_score[i][j]>=max){
					max=other_score[i][j]+target_score[i][j];
					*x=i;*y=j;
				}
			}
		}
/*
//用于调试，输出各点的分数，会被system("clear")清除掉。
	for(i=0;i<SIZE;i++)
	for(j=0;j<SIZE;j++)
		if(other_score[i][j] || target_score[i][j])
		printf("other_score[%d][%d]:%d\ntarget_score[%d][%d]:%d\n",i,j,other_score[i][j],i,j,target_score[i][j]);
	
	printf("max=%d\n",max);
*/


//VCT与VCF思路
//使用static型为递归计数，用int型记录当前static参数值，static参数++，如果static参数小于指定的次数：
	//max<=1000分，且当前目标的某点是活三跳活三冲四，模拟在该点落子
	//调用AIgetchess为另一方选择一点(a,b)并在该点模拟落子

	//重新计算分数，取消模拟落的子，如果当前目标有制胜点，记可以赢，如果static==1,更改*x，*y为i，j。
	//如果没有：
		//如果另一方的某点是活三冲四，模拟在该点落子
		//调用AIgetchess为当前目标选择一点(a,b)并在该点模拟落子

		//重新计算分数，取消模拟落的子，如果另一方有制胜点，记可以赢，如果static==1,更改*x，*y为i，j。
//static参数记回本次递归前的值




//首先需要做的：把外部定义的数组改为内部定义，并初始化，并传入,clear_mydata,getscore和gettype，并引入当前目标的棋子变量
//复习线代物理T^T

	struct lnode *p;
	int a,b,i1,j1,i2,j2;
	int digui_max1,digui_max2;

	struct lnode *target_type2[SIZE][SIZE];
	struct lnode *other_type2[SIZE][SIZE];


//通过双重循环，初始化两个数组
	for(i=0;i<SIZE;i++)
	for(j=0;j<SIZE;j++){
		target_type2[i][j]=NULL;
		other_type2[i][j]=NULL;

	}


	int remember;

//用于记录是否可以取胜
	static int keyi=0;



//开始计算

	remember=countdigui;
	if(max<=1000&&countdigui<=20&&!keyi){
	
	
						countdigui++;

//为当前目标递归
			for(i1=0;i1<SIZE;i1++)
			for(j1=0;j1<SIZE;j1++){
			for(p=target_type[i1][j1];p!=NULL;p=p->next){

				if(	(p->huo==1||p->huo==2)&&p->number==3||p->huo==0&&p->number==4	){


					

					
					aRecordBoard[i1][j1]=targetchess;

					
					AIgetchess(&a,&b,otherchess);
					aRecordBoard[a][b]=otherchess;



					clear_mydata(target_score,other_score,target_type2,other_type2);
					gettype(target_type2,targetchess);
					gettype(other_type2,otherchess);
					getscore(NULL,target_score,other_score,target_type2,other_type2);
					
					digui_max1=digui_max2=0;
					for(i2=0;i2<SIZE;i2++)
					for(j2=0;j2<SIZE;j2++){
						if(target_score[i2][j2]>digui_max1){digui_max1=target_score[i2][j2];
						
						}
						
						if(other_score[i2][j2]>digui_max2){digui_max2=other_score[i2][j2];
						
						}
					}
					aRecordBoard[i1][j1]=0;
					aRecordBoard[a][b]=0;
					

					
					if(digui_max1>=digui_max2&&digui_max1>1000){
						keyi=1;	
//挑衅
						if(targetchess==computerchess)
						printf("嘿嘿");

					}
				}
				if(countdigui==1 && keyi){
					*x=i1;*y=j1;

					return;
				}
			}
			}


//为另一方递归
			if(!keyi){	
				for(i1=0;i1<SIZE;i1++)
				for(j1=0;j1<SIZE;j1++){
				for(p=other_type[i1][j1];p!=NULL;p=p->next){
					if(	(p->huo==1||p->huo==2)&&p->number==3||p->huo==0&&p->number==4	){
						aRecordBoard[*x][*y]=targetchess;
						
						
						aRecordBoard[i1][j1]=otherchess;
						
							
						AIgetchess(&a,&b,targetchess);
						aRecordBoard[a][b]=targetchess;
						
						
						clear_mydata(target_score,other_score,target_type2,other_type2);
						gettype(target_type2,otherchess);
						gettype(other_type2,targetchess);
						getscore(NULL,target_score,other_score,target_type2,other_type2);
						digui_max1=digui_max2=0;
						for(i2=0;i2<SIZE;i2++)
						for(j2=0;j2<SIZE;j2++){
							if(target_score[i2][j2]>digui_max1)digui_max1=target_score[i2][j2];
							if(other_score[i2][j2]>digui_max2)digui_max2=other_score[i2][j2];
							}
						aRecordBoard[i1][j1]=0;
						aRecordBoard[a][b]=0;
						aRecordBoard[*x][*y]=0;
						
							
						if(digui_max1>=digui_max2&&digui_max1>1000){
							keyi=1;	
							}
					}
					if(countdigui==1 && keyi){
						*x=i1;*y=j1;
							return;
					}
				}
				}
			}
	}

	countdigui=remember;
	if(countdigui==0)
		keyi=0;

}

//通过双重循环，将type和score数组清空
void clear_mydata(int target_score[SIZE][SIZE],int other_score[SIZE][SIZE],struct lnode *target_type[SIZE][SIZE],struct lnode *other_type[SIZE][SIZE]){
	int i,j;
	struct lnode *p,*q;
	for(i=0;i<SIZE;i++)
		for(j=0;j<SIZE;j++){
			target_score[i][j]=0;
			other_score[i][j]=0;

			if(target_type!=NULL){

				if(target_type[i][j]!=NULL){
					p=target_type[i][j];
					q=p->next;
					free(p);
					target_type[i][j]=NULL;
					while(q!=NULL){
						p=q;
						q=p->next;
						free(p);
					}
				}
			}

			if(other_type!=NULL){

				if(other_type[i][j]!=NULL){
					p=other_type[i][j];
					q=p->next;
					free(p);
					other_type[i][j]=NULL;
					while(q!=NULL){
						p=q;
						q=p->next;
						free(p);
					}
				}
			}
		}
}


//评分
void getscore(int *temp,int target_score[SIZE][SIZE],int other_score[SIZE][SIZE],struct lnode *target_type[SIZE][SIZE],struct lnode *other_type[SIZE][SIZE]){
	int i,j;
	struct lnode *p;
	int wulian,huosi,chongsi,huosan,miansan,huoer,tiaohuosan,datiaohuoer;
	for(i=0;i<SIZE;i++)
		for(j=0;j<SIZE;j++){
			wulian=huosi=chongsi=huosan=tiaohuosan=miansan=huoer=datiaohuoer=0;
			for(p=target_type[i][j];p!=NULL;p=p->next){
				if(p->number==5)
					wulian+=p->n;					
				else if(p->huo==1 && p->number==4)
					huosi+=p->n;
				else if(p->huo==0 && p->number==4)
					chongsi+=p->n;
				else if(p->huo==1 && p->number==3)
					huosan+=p->n;
				else if(p->huo==2 && p->number==3)
					tiaohuosan+=p->n;
				else if(p->huo==0 && p->number==3)
					miansan+=p->n;
				else if(p->huo==1 && p->number==2)
					huoer+=p->n;
				else if(p->huo==0 && p->number==2)
					datiaohuoer+=p->n;
			}
			if(wulian>0)
				target_score[i][j]=10000;
			else if(huosi>0 || chongsi>=2 || chongsi==1&&huosan+tiaohuosan>0)
				target_score[i][j]=8000;
			else if(huosan+tiaohuosan>1)
				target_score[i][j]=6000;
			else{
				target_score[i][j]=chongsi*49+huosan*100+tiaohuosan*99+miansan*25+huoer*30+datiaohuoer*29;
				if(chongsi&&miansan)
					other_score[i][j]+=miansan*20;
				if(chongsi&&(huoer+datiaohuoer))
					other_score[i][j]+=(huoer+datiaohuoer)*20;
			}

			if(temp!=NULL){
				*temp=chongsi*49+huosan*100+tiaohuosan*99+miansan*25+huoer*30+datiaohuoer*29;
				if(chongsi&&miansan)
					*temp+=miansan*20;
				if(chongsi&&(huoer+datiaohuoer))
					*temp+=(huoer+datiaohuoer)*20;
			}
		}

	

	for(i=0;i<SIZE;i++)
		for(j=0;j<SIZE;j++){
			wulian=huosi=chongsi=huosan=tiaohuosan=miansan=huoer=datiaohuoer=0;
			for(p=other_type[i][j];p!=NULL;p=p->next){
				if(p->number==5)
					wulian+=p->n;					
				else if(p->huo==1 && p->number==4)
					huosi+=p->n;
				else if(p->huo==0 && p->number==4)
					chongsi+=p->n;
				else if(p->huo==1 && p->number==3)
					huosan+=p->n;
				else if(p->huo==2 && p->number==3)
					tiaohuosan+=p->n;
				else if(p->huo==0 && p->number==3)
					miansan+=p->n;
				else if(p->huo==1 && p->number==2)
					huoer+=p->n;
				else if(p->huo==0 && p->number==2)
					datiaohuoer+=p->n;
			}
			if(wulian>0){
				other_score[i][j]=9000;
				other_score[i][j]+=chongsi*50+huosan*98+tiaohuosan*97+miansan*20+huoer*30;

			}
			else if(huosi>0){
				other_score[i][j]=7000;
				other_score[i][j]+=chongsi*50+huosan*98+tiaohuosan*97+miansan*20+huoer*30;

			}
			else if(chongsi>=2){
				other_score[i][j]=7000;
				other_score[i][j]+=(chongsi-2)*50+huosan*98+tiaohuosan*97+miansan*20+huoer*30;

			}
			else if(chongsi==1 && huosan+tiaohuosan>=1){
				other_score[i][j]=7000;
				other_score[i][j]+=(chongsi-1)*50+(huosan+tiaohuosan-1)*(huosan?98:97)+miansan*20+huoer*30;

				
			}
			else if(huosan+tiaohuosan>1){
				other_score[i][j]=5000;
				other_score[i][j]+=chongsi*50+(huosan+tiaohuosan-2)*(huosan?98:97)+miansan*20+huoer*30;

				
			}
			else{
				other_score[i][j]=chongsi*50+huosan*98+tiaohuosan*97+miansan*20+huoer*30;
				if(chongsi&&miansan)
					other_score[i][j]+=miansan*20;
				if(chongsi&&huoer)
					other_score[i][j]+=huoer*20;
			}
		
		}
}

//获得所有空点的棋型数据
//huo=1表示活，huo=0表示眠或冲，number代表多少个棋相连的棋型，n代表棋型数量

void gettype(struct lnode *type[SIZE][SIZE],int chess){
	int x,y;
	int i;
	int number11,number21,number12,number22,skip1,havespace1,skip2,havespace2;

	for(x=0;x<SIZE;x++)
		for(y=0;y<SIZE;y++)
			if(aRecordBoard[x][y]==0){
//横向
//采集数据
				number11=1;number21=1;number12=0;number22=0;
				skip1=0;havespace1=0;skip2=0;havespace2=0;

				for(i=1;;i++){
					if(y-i<0 || aRecordBoard[x][y-i]==((chess==1)?2:1)){
						if(number12==0){
							havespace1=skip1;
							skip1=0;
							break;
						}
						else
							break;
					}
					else if(aRecordBoard[x][y-i]==chess){
						if(!skip1)
							number11++;
						else if(!havespace1)
							number12++;
						else
							break;
					}
					else if(aRecordBoard[x][y-i]==0){
						if(number12==0)
							skip1++;
						else 
							havespace1++;
					}
				}

				for(i=1;;i++){
					if(y+i>=SIZE || aRecordBoard[x][y+i]==((chess==1)?2:1)){
						if(number22==0){
							havespace2=skip2;
							skip2=0;
							break;
						}
						else
							break;
					}
					else if(aRecordBoard[x][y+i]==chess){
						if(!skip2)
							number21++;
						else if(!havespace2)
							number22++;
						else
							break;
					}
					else if(aRecordBoard[x][y+i]==0){
						if(number22==0)
							skip2++;
						else 
							havespace2++;
					}
				}
							

//分析数据
			analysedata(number11,number21,number12,number22,skip1,havespace1,skip2,havespace2,x,y,type);		

			


//纵向

//采集数据
				number11=1;number21=1;number12=0;number22=0;
				skip1=0;havespace1=0;skip2=0;havespace2=0;

				for(i=1;;i++){
					if(x-i<0 || aRecordBoard[x-i][y]==((chess==1)?2:1)){
						if(number12==0){
							havespace1=skip1;
							skip1=0;
							break;
						}
						else
							break;
					}
					else if(aRecordBoard[x-i][y]==chess){
						if(!skip1)
							number11++;
						else if(!havespace1)
							number12++;
						else
							break;
					}
					else if(aRecordBoard[x-i][y]==0){
						if(number12==0)
							skip1++;
						else 
							havespace1++;
					}
				}

				for(i=1;;i++){
					if(x+i>=SIZE || aRecordBoard[x+i][y]==((chess==1)?2:1)){
						if(number22==0){
							havespace2=skip2;
							skip2=0;
							break;
						}
						else
							break;
					}
					else if(aRecordBoard[x+i][y]==chess){
						if(!skip2)
							number21++;
						else if(!havespace2)
							number22++;
						else
							break;
					}
					else if(aRecordBoard[x+i][y]==0){
						if(number22==0)
							skip2++;
						else 
							havespace2++;
					}
				}
			

//分析数据
			analysedata(number11,number21,number12,number22,skip1,havespace1,skip2,havespace2,x,y,type);		

			

			


//左斜
//采集数据
				number11=1;number21=1;number12=0;number22=0;
				skip1=0;havespace1=0;skip2=0;havespace2=0;

				for(i=1;;i++){
					if(x-i<0|| y+i>=SIZE || aRecordBoard[x-i][y+i]==((chess==1)?2:1)){
						if(number12==0){
							havespace1=skip1;
							skip1=0;
							break;
						}
						else
							break;
					}
					else if(aRecordBoard[x-i][y+i]==chess){
						if(!skip1)
							number11++;
						else if(!havespace1)
							number12++;
						else
							break;
					}
					else if(aRecordBoard[x-i][y+i]==0){
						if(number12==0)
							skip1++;
						else 
							havespace1++;
					}
				}

				for(i=1;;i++){
					if(x+i>=SIZE || y-i<0 || aRecordBoard[x+i][y-i]==((chess==1)?2:1)){
						if(number22==0){
							havespace2=skip2;
							skip2=0;
							break;
						}
						else
							break;
					}
					else if(aRecordBoard[x+i][y-i]==chess){
						if(!skip2)
							number21++;
						else if(!havespace2)
							number22++;
						else
							break;
					}
					else if(aRecordBoard[x+i][y-i]==0){
						if(number22==0)
							skip2++;
						else 
							havespace2++;
					}
				}
			

			
//分析数据
			analysedata(number11,number21,number12,number22,skip1,havespace1,skip2,havespace2,x,y,type);		




//右斜

//采集数据
				number11=1;number21=1;number12=0;number22=0;
				skip1=0;havespace1=0;skip2=0;havespace2=0;

				for(i=1;;i++){
					if(x-i<0 || y-i<0 || aRecordBoard[x-i][y-i]==((chess==1)?2:1)){
						if(number12==0){
							havespace1=skip1;
							skip1=0;
							break;
						}
						else
							break;
					}
					else if(aRecordBoard[x-i][y-i]==chess){
						if(!skip1)
							number11++;
						else if(!havespace1)
							number12++;
						else
							break;
					}
					else if(aRecordBoard[x-i][y-i]==0){
						if(number12==0)
							skip1++;
						else 
							havespace1++;
					}
				}

				for(i=1;;i++){
					if(x+i>=SIZE|| y+i>=SIZE || aRecordBoard[x+i][y+i]==((chess==1)?2:1)){
						if(number22==0){
							havespace2=skip2;
							skip2=0;
							break;
						}
						else
							break;
					}
					else if(aRecordBoard[x+i][y+i]==chess){
						if(!skip2)
							number21++;
						else if(!havespace2)
							number22++;
						else
							break;
					}
					else if(aRecordBoard[x+i][y+i]==0){
						if(number22==0)
							skip2++;
						else 
							havespace2++;
					}
				}
			
//分析数据
			analysedata(number11,number21,number12,number22,skip1,havespace1,skip2,havespace2,x,y,type);	

		
		}

	return;
			
}	




//分析数据
void analysedata(int number11,int number21,int number12,int number22,int skip1,int havespace1,int skip2,int havespace2,int x,int y,struct lnode* type[SIZE][SIZE]){

//五连
	if(skip1!=1 && skip2!=1 && number11+number21-1>=5){
		writelnode(1,5,1,x,y,type);
	}
		
		
	else{
//活四
		if(number11+number21-1==4 && 
(skip1==0&&skip2==0&&havespace1&&havespace2 || skip1&&skip2 || skip1&&skip2==0&&havespace2 || skip2&&skip1==0&&havespace1) 
			){
			writelnode(1,4,1,x,y,type);
		}

//两个冲四
		else if((skip1==1&&(number11+number12+number21-1>=4)) && (skip2==1&&(number21+number22+number11-1>=4))){
			writelnode(0,4,2,x,y,type);
		}

//一个冲四
		else if((skip1==1&&(number11+number12+number21-1>=4)) ^ (skip2==1&&(number21+number22+number11-1>=4)) || 

number11+number21-1==4 && ( (skip1==0&&havespace1==0)&&(skip2||skip2==0&&havespace2) || (skip2==0&&havespace2==0)&&(skip1||skip1==0&&havespace1) )
				){
			writelnode(0,4,1,x,y,type);
		}		


//活三加眠三
		else if(
(	(havespace1 || havespace2) && skip1==1 && skip2==1 && number11+number21-1==2 && number12==1 && number22==1	) || 
(	skip1==1 && skip2==1 && number11+number21-1==1 && (number12==2&&havespace1 || number22==2&&havespace2)	)
						){
						writelnode(1,3,1,x,y,type);
						writelnode(0,3,1,x,y,type);
					}		
			
//连活三	
		else if(
number11+number21-1==3 && (skip1==0&&skip2==0&&havespace1&&havespace2&&havespace1+havespace2>=3 || 
skip1==0&&skip2>=2&&havespace1 || 
skip2==0&&skip1>=2&&havespace2 ||
skip1>=2&&skip2>=2)
					){
			writelnode(1,3,1,x,y,type);
		}
//跳活三，以huo=2表示
		else if(

( skip1==1&&number11+number21+number12-1==3&&havespace1&&(skip2||havespace2)
||skip2==1&&number11+number21+number22-1==3&&havespace2&&(skip1||havespace1)
)

				){
			writelnode(2,3,1,x,y,type);

		}



//不太完善的眠三，1010X棋型不能识别
		else if(
(	(!havespace2&&skip1>=2&&number11+number21-1==3)||(!havespace1&&skip2>=2&&number11+number21-1==3)	) ||

(	(havespace1&&!havespace2&&skip1==1&&number11+number21-1+number12==3 || havespace2&&!havespace1&&skip2==1&&number11+number21-1+number22==3)	)||

(	!skip1&&!skip2&&number11+number21-1==3&&havespace1==1&&havespace2==1	)||

(	number11+number21-1==1&&skip1==1&&skip2==1&&number12==1&&number22==1	)
			){
				writelnode(0,3,1,x,y,type);
		}
		else if( (skip1==2&&number11+number21-1<=2&&number11+number21-1+number12>=3)||(skip2==2&&number11+number21-1<=2&&number11+number21-1+number22>=3)
			){
				if(skip1==2&&number11+number21-1<=2&&number11+number21-1+number12>=3)
					writelnode(0,3,1,x,y,type);
				if(skip2==2&&number11+number21-1<=2&&number11+number21-1+number22>=3)
					writelnode(0,3,1,x,y,type);
		}
		
//活二
		else if(number11+number21-1==2&&(skip1>=3||skip1==0&&havespace1>=3)&&(skip2>=3||skip2==0&&havespace2>=3) || 

		(	number11+number21-1==1&&
(skip1==1&&number12==1&&havespace1&&(havespace2&&havespace1+havespace2>=3||skip2>=2) || 
skip2==1&&number22==1&&havespace2&&(havespace1&&havespace1+havespace2>=3||skip1>=2))	)
				){
					writelnode(1,2,1,x,y,type);
		}
//大跳活二，以huo=0表示
		else if(	
			number11+number21-1==1&&(
skip1==2&&number12==1&&havespace1>=1&&(skip2>=1||skip2==0&&havespace2>=1)||skip2==2&&number22==1&&havespace2>=1&&(skip1>=1||skip1==0&&havespace1>=1)
			)
				){
					writelnode(0,2,1,x,y,type);
		}
	}
}





void writelnode(int huo,int number,int n,int x,int y,struct lnode *type[SIZE][SIZE]){
	struct lnode *p,*q;
	for(p=type[x][y];p!=NULL;p=p->next)
		if(p->huo==huo && p->number==number){
			p->n+=n;
			break;
		}
	if(p==NULL){
		q=(struct lnode*)malloc(sizeof(struct lnode));
		if(q!=NULL){
			q->huo=huo;
			q->number=number;
			q->n=n;
			q->next=NULL;
			if(type[x][y]==NULL)
				type[x][y]=q;
			else{
				for(p=type[x][y];p->next!=NULL;p=p->next);
				p->next=q;
			}
		}
		else
			printf("malloc内存不足\n");
	}

}
		

	
//输入函数，得到玩家输入的坐标，支持quit，不支持悔棋
int getchess(int *x,int *y){
	int c,d;
	while((c=getchar())==' ' || c=='\t');
	if(c>='1' && c<='9'){
		d=getchar();
		if(d>='0' && d<='5'){
			*x=15-((c-'0')*10+(d-'0'));
			if(*x<0 || *x>14)
				goto error;
			d=getchar();
			if(d==',' || d==' '){
				while((d=getchar())==' ');
				if((d>='A' && d<='O') || (d>='a' && d<='o')){
					*y=d-((d>='A' && d<='O')?'A':'a');
					while((d=getchar())==' ' || d=='\t');
					if(d=='\n' || d==EOF)
						return 0;
					else
						goto error;
				}
				else
					goto error;
			}
			else if((d>='A' && d<='O') || (d>='a' && d<='o')){
				*y=d-((d>='A' && d<='O')?'A':'a');
				while((d=getchar())==' ' || d=='\t');
				if(d=='\n' || d==EOF)
					return 0;
				else
					goto error;
			}
			else
				goto error;
		}
		else if(d==',' || d==' '){
			*x=15-(c-'0');
			while((d=getchar())==' ');
			if((d>='A' && d<='O') || (d>='a' && d<='o')){
				*y=d-((d>='A' && d<='O')?'A':'a');
				while((d=getchar())==' ' || d=='\t');
				if(d=='\n' || d==EOF)
					return 0;
				else
					goto error;
			}
			else
				goto error;
		}
		else if((d>='A' && d<='O') || (d>='a' && d<='o')){
			*x=15-(c-'0');
			*y=d-((d>='A' && d<='O')?'A':'a');
			while((d=getchar())==' ' || d=='\t');
			if(d=='\n' || d==EOF)
				return 0;
			else
				goto error;
		}
		else
			goto error;
	}

	else if((c>='A' && c<='O') || (c>='a' && c<='o')){
		*y=c-((c>='A' && c<='O')?'A':'a');
		if((c=getchar())==',' || c==' '){
			while((c=getchar())==' ');
			if(c>='1' && c<='9'){
				if((d=getchar())>='0' && d<='5'){
					*x=15-((c-'0')*10+(d-'0'));
					if(*x<0 || *x>14)
						goto error;
					else{
						while((d=getchar())==' ' || d=='\t');
						if(d=='\n' || d==EOF)
							return 0;
						else
							goto error;
					}
				}
				else if(d==' ' || d=='\t'){
					*x=15-(c-'0');
					while((d=getchar())==' ' || d=='\t');
					if(d=='\n' || d==EOF)
						return 0;
					else
						goto error;
				}
				else if(d=='\n' || d==EOF){
					*x=15-(c-'0');
					return 0;
				}		
				else 
					goto error;
			}
			else 
				goto error;
		}
		else if(c>='1' && c<='9'){
			if((d=getchar())>='0' && d<='5'){
				*x=15-((c-'0')*10+(d-'0'));
				if(*x<0 || *x>14)
					goto error;
				else{
						while((d=getchar())==' ' || d=='\t');
						if(d=='\n' || d==EOF)
							return 0;
						else
							goto error;
				}
			}
			else if(d==' ' || d=='\t'){
				*x=15-(c-'0');
				while((d=getchar())==' ' || d=='\t');
				if(d=='\n' || d==EOF)
					return 0;
				else
					goto error;
			}
			else if(d=='\n' || d==EOF){
				*x=15-(c-'0');
				return 0;
			}		
			else 
				goto error;
		}

		else 
			goto error;
	}
	else if(c=='q' && (c=getchar())=='u' && (c=getchar())=='i' && (c=getchar())=='t'){
		while((c=getchar())==' ' || c=='\t');
		if(c=='\n' || c==EOF)
			return 2;
		else
			goto error;
	}
	/*else if(c=='r' && (c=getchar())=='e' && (c=getchar())=='g' && (c=getchar())=='r' && (c=getchar())=='e' && (c=getchar())=='t'){
		while((c=getchar())==' ' || c=='\t');
		if(c=='\n' || c==EOF)
			return 3;
		else
			goto error;
	}*/
	else
		goto error;
	
	
		


	error:
		while((c=getchar())!='\n' && c!=EOF);
		printf("Usage: 以任意次序输入横坐标与纵坐标，中间不隔开或以任意数量空格或\"，\"隔开，以回车或EOF结束。输入quit以返回。\n");
		return 1;
		
}









		



void initRecordBoard(void){
//通过双重循环，将aRecordBoard清0
	int i,j;
	for(i=0;i<SIZE;i++)
		for(j=0;j<SIZE;j++){
			aRecordBoard[i][j]=0;
		}
}

//将aRecordBoard中记录的棋子位置，转化到aDisplayBoardArray中
void recordtoDisplayArray(void){
//第一步：将aInitDisplayBoardArray中记录的空棋盘，复制到aDisplayBoardArray中
//第二步：扫描aRecordBoard，当遇到非0的元素，将●或者◎复制到aDisplayBoardArray的相应位置上
//注意：aDisplayBoardArray所记录的字符是中文字符，每个字符占2个字节。●和◎也是中文字符，每个也占2个字节。
	int i,j;
	for(i=0;i<SIZE;i++)
		for(j=0;j<SIZE*CHARSIZE+1;j++){
			aDisplayBoardArray[i][j]=aInitDisplayBoardArray[i][j];
		}
	for(i=0;i<SIZE;i++)
		for(j=0;j<SIZE;j++){
			if (aRecordBoard[i][j]==1){
			aDisplayBoardArray[i][j*CHARSIZE]=play1Pic[0];
			aDisplayBoardArray[i][j*CHARSIZE+1]=play1Pic[1];
			}
			if (aRecordBoard[i][j]==2){
			aDisplayBoardArray[i][j*CHARSIZE]=play2Pic[0];
			aDisplayBoardArray[i][j*CHARSIZE+1]=play2Pic[1];
			}
		}
}

//显示棋盘
void displayBoard(void){
	int i;
	//第一步：清屏
	system("clear");   //清屏  
	//第二步：将aDisplayBoardArray输出到屏幕上
	printf("\t   ========Welcome to Five-in-Row Game========\n");
	for(i=0;i<SIZE;i++)	
	printf("\t\t%2d %s\n",15-i,aDisplayBoardArray[i]);
	
	printf("\t\t   A B C D E F G H I J K L M N O \n");
} 

//Judge whether someone win the game
int win(int x,int y){
	int i=-5,count1=0,count2=0,count3=0,count4=0;
	int flag=aRecordBoard[x][y];
	while(count1!=5 && count2!=5 && count3!=5 && count4!=5 && ++i<5){
		if(y+i>=0 && y+i<SIZE){
			if(aRecordBoard[x][y+i]==flag)
				count1++;
			else
				count1=0;
		}
		if(x+i>=0 && x+i<SIZE){
			if(aRecordBoard[x+i][y]==flag)
				count2++;
			else
				count2=0;
		}
		if(x+i>=0 && x+i<SIZE && y+i>=0 && y+i<SIZE){
			if(aRecordBoard[x+i][y+i]==flag)
				count3++;
			else
				count3=0;
		}
		if(x+i>=0 && x+i<SIZE && y-i>=0 && y-i<SIZE){
			if(aRecordBoard[x+i][y-i]==flag)
				count4++;
			else
				count4=0;
		}
	}
	if(count1==5 || count2==5 || count3==5 || count4==5)
		return 1;
	else
		return 0;
}

//判断是否棋盘已满
int isfull(void){
	int i,j,state=1;
	for(i=0;i<SIZE;i++)
		for(j=0;j<SIZE;j++)
			if(aRecordBoard[i][j]==0)
				state=0;
			
	return state;
}
