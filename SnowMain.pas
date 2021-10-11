unit SnowMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, ComCtrls, StdCtrls;

type
  TForm1 = class(TForm)
    Timer1: TTimer;
    PaintBox1: TPaintBox;
    TrackBar1: TTrackBar;
    CheckBox1: TCheckBox;
    Panel1: TPanel;
    ComboBox1: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    procedure Timer1Timer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

type
   // ici le type pScanArray nous permet de recuperer les 4096 pixels maximum
   // transmit par Bitmap.ScanLine, c'est un pointeur sur le type TScanArray
   pScanArray = ^TScanArray;
   TScanArray = array[0..4095] of integer;

var
   Buffer : TBitmap; // buffer pour l'effet

function Max(const A,B : integer) : integer;
begin
  if B > A then 
    result := B
  else
    result := A;
end;

// fonction permettant de créer un niveau de gris a partir d'un simple byte.   
function CreateGray(const B : byte) : integer;
begin
  result := B + (B shl 8) + (B shl 16);
end;

// L'effet neige, simple a utiliser.
procedure FX_Snow(const SnowCount, GroundColor : integer; const ShowScan : boolean; Bitmap : Tbitmap);
var N,
	  X,Y,
	  CB  : integer;
   
	// en reglant TScanArray a 4096 valeur on obtient 3 buffer de 16Ko maxi ce qui est raisonnable et suffisant
	PSA0,
	PSA1,
	PSA2 : pScanArray; 
    
	XOK1,
	YOK1,
  XOK2,
	YOK2 : boolean;
    
	Col0,
	Col1,
	Col2 : integer;
begin
  // on remplis le fond de l'image
  Bitmap.Canvas.Brush.Color := GroundColor;
  Bitmap.Canvas.FillRect(Rect(0,0,Bitmap.Width,Bitmap.Height));

  // si SnowCount est a 0 ou inferieur on perd pas de temps et on quitte
  if SnowCount <= 0 then
     exit;

  for N := 0 to Snowcount do begin
      // on recupere des coordonnées aleatoire pour placer le point
      X := Random(Bitmap.Width);
      Y := Random(Bitmap.Height);
	  
	  // on recupere une valeur aleatoire 0..255 pour le niveau de gris
      CB:= Random(256);

	  // on verifit quelques conditions
      XOK1 := X > 0;
      XOK2 := X < Bitmap.Width-1;
      YOK1 := Y > 0;
      YOK2 := Y < Bitmap.Height-1;

	  // si tout est OK, on peu créer l'image
      if (YOK1 and YOK2) and (XOK1 and XOK2) then begin
	     
		 // on crée la couleur principale
         Col0 := CreateGray(CB);
		 
         // on l'assigne au point aleatoire
         PSA0 := Bitmap.ScanLine[Y];
         PSA0[X]   := Col0;

		 // si on utilise pas l'effet scanline on vas afficher de gros points
         if not ShowScan then begin
		    
			// a condition que la couleur aleatoire soit superieure a 0
            if CB > 0 then begin
			   // on calcul les deux autres niveaux pour avoir un plus bel effet
			   // [couleur-33%] [couleur-20%] [couleur-33%]
			   // [couleur-20%] [couleur    ] [couleur-20%]
			   // [couleur-33%] [couleur-20%] [couleur-33%]
		   
               Col1 := CreateGray(max(CB-(CB div 5),0));
               Col2 := CreateGRay(max(CB-(CB div 3),0));
            end else begin
			   // sinon c'est du noir
               Col1 := 0;
               Col2 := 0;
            end;

			// ici rien de bien complexe, on crée un carré de 3x3 pixel autour du premier
			// point ...
			// [x-1, y-1] [x  , y-1] [x+1, y-1]  = PSA1
			// [x-1, y  ] [x  , y  ] [x+1, y  ]  = PSA0
			// [x-1, y+1] [x  , y+1] [x+1, y+1]  = PSA2
			
            // on recupere la ligne au dessus et en dessous du point d'origine (x,y)
            PSA1 := Bitmap.ScanLine[Y-1];
            PSA2 := Bitmap.ScanLine[Y+1];

            PSA1[X-1] := Col2;
            PSA1[X]   := Col1;
            PSA1[X+1] := Col2;

            PSA0[X-1] := Col1;
			// PSA0[X] a deja ete assigné plus haut 
            PSA0[X+1] := Col1;

            PSA2[X-1] := Col2;
            PSA2[X]   := Col1;
            PSA2[X+1] := Col2;
         end;
      end;
   end;

   // enfin, si on utilise l'effet de scanline
   if ShowScan then
      // on remplis avec la couleur de fond toutes les lignes paires
      for Y := 0 to Bitmap.height-1 do
	      // astuce Y mod 2 est egale a 0 si Y est pair et different de 0 si impair.
          if (Y mod 2) = 0 then begin
             PSA0 := Bitmap.ScanLine[Y];
             for X := 0 to Bitmap.Width-1 do
                 PSA0[X] := GroundColor;
          end;

end;

// a la creation de la fiche
procedure TForm1.FormCreate(Sender: TObject);
begin
  Randomize;

  // on crée le buffer, ici on gagneras du temps en evitant des milliers de
  // creations/destructions du buffer a chaque creation d'image.
  Buffer             := Tbitmap.Create;
  Buffer.PixelFormat := pf32bit; // 32 bits car on utilise un Array of integer pour les couleurs
                                 // cela est notemant plus rapide qu'en 24bits et mieux qu'en 16bits
								 // bien qu'avec les niveaux de gris on pourrait travailler qu'en 16bits
								 // mais moins evident et simple ...
  Buffer.Width       := PaintBox1.Width+8;
  Buffer.Height      := PaintBox1.Height+8;

  // on demarre le timer
  Timer1.Enabled  := true;

  {
   Comme nous le suggere Cirec, ici le doublebuffer est inutile puisque c'est le bitmap
   qui nous sert de double buffer.
   on peu donc ignorer l'evenement OnPaint de la PaintBox et la mise a true du doublebuffered
   de la fiche.
   Cale fait gagner en cycles CPU et en ressources.
  }
end;

// a la destruction de la fiche
procedure TForm1.FormDestroy(Sender: TObject);
begin
  // on libere le buffer
  Buffer.Free;
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
begin
end;

// le timer
procedure TForm1.Timer1Timer(Sender: TObject);
begin
  // on redimensionne le buffer a la taille de la paintbox, au cas ou
  Buffer.Width  := PaintBox1.Width+8;
  Buffer.Height := PaintBox1.Height+8;

  // on applique l'effet sur le buffer
  FX_Snow(TrackBar1.Position shl 2, $121212, CheckBox1.Checked, Buffer);

  // on dessine le buffer dans le canvas de paintbox
  PaintBox1.Canvas.Draw(-4,-4,Buffer);
end;

// La trackbar qui permet de modifier le nombre de points dans l'effet
procedure TForm1.TrackBar1Change(Sender: TObject);
begin
  // nombre de point qu'on affiche dans un label 
  // shl 2 correspond a une multiplication par 4 mais consome moins de cycles CPU qu'une multiplication
  // cela permet de garder l'interval 0..10000 de la trackbar, bien qu'on aurait pus lui definir 
  // un interval plus grand, mais cela permet de montrer la technique de multiplication via SHL
  Label2.Caption := Format('Bruit (%d) :',[TrackBar1.Position shl 2]);
end;

// OnChange du ComboBox1 qui permet de definir le FPS desiré
procedure TForm1.ComboBox1Change(Sender: TObject);
begin
  // FPS = Frames Per Second (images par secondes)
  // l'interval du timer est exprimé en millisecondes
  // il faut donc diviser 1000 (1 seconde) par le nombre de FPS voulus
  // pour obtenir l'interval en MS entre chaque refresh.
  // plus le FPS est elevé, plus l'interval en ms serat court.
  // retenez bien cela car il est inutile, dans une application graphique,
  // d'aller au dela de 30FPS avec la GDI et que votre application
  // serat moins gourmande en ressources CPU si vous mettez un interval de 40ms au lieu 
  // d'un interval a 1 ms (~1000FPS) ou 20 ms (50 FPS)...
  // cela fait egalement partit des optimisations vitale qui permettent d'augmenter 
  // la fluiditée d'un programme, d'une animation image par image, d'un deplacement d'objet 
  // par incrementation de position (Left/Top -/+ n).
  case ComboBox1.ItemIndex of
    0 : Timer1.Interval := 1000 div 12; // 83 ms
    1 : Timer1.Interval := 1000 div 20; // 50 ms
    2 : Timer1.Interval := 1000 div 23; // 43 ms
    3 : Timer1.Interval := 1000 div 25; // 40 ms
    4 : Timer1.Interval := 1000 div 30; // 33 ms
  end;
  // il n'est pas necessaire ici de desactiver et reactiver le timer pour changer 
  // l'interval, le timer le fait de lui meme, il se peut par contre que dans certains
  // cas vous soyez obliger de le faire, mais cela reste rare.
end;

end.
