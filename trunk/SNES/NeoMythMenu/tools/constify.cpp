/*
	Constify - A tool for the SNES-SDK
	Mic, 2010

	Moves const data from .data/.ram.data to .rodata
*/

#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <vector>
#include <iterator>


using namespace std;

vector<string> constVars;
vector<string> asmSections[3];

void check_for_const(string s)
{
	int i, j;

	if ( (s.find("const") != string::npos) && (s.find("extern") == string::npos) )
	{
		for (i = 0; i < s.length(); i++)
		{
			if ((s[i] == '=') || (s[i] == '['))
			{
				break;
			}
		}

		if (i < s.length())
		{
			while ((s[i] == ' ') || (s[i] == '\t'))
			{
				i--;
			}
			j = i - 1;
			while ((s[j] != ' ') && (s[j] != '\t') && (s[j] != '*'))
			{
				j--;
			}

			//printf("Found const named %s\n", s.substr(j + 1, i-j-1).data());
			constVars.push_back(s.substr(j + 1, i-j-1));
		}
	}
}


int main(int argc, char **argv)
{
	FILE *cFile, *asmFile, *outFile;
	string oneLine;
	bool saveCode;
	int i, j, varOffs, varSize, varsMoved, bytesMoved, ch, currSection;

	if (argc < 4)
	{
		puts("Usage: constify cfile asmfile output");
		return 0;
	}

	// Find all const variables that and store them in constVars
	cFile = fopen(argv[1], "rb");
	oneLine.clear();
	while (1)
	{
		if ((ch = fgetc(cFile)) != EOF)
		{
			if ((ch == 10) || (ch == 13))
			{
				check_for_const(oneLine);
				oneLine.clear();
			}
			else
			{
				oneLine += (char)ch;
			}
		}
		else
		{
			check_for_const(oneLine);
			break;
		}
	}
	fclose(cFile);


	asmFile = fopen(argv[2], "rb");
	outFile = fopen(argv[3], "wb");

	oneLine.clear();
	saveCode = false;
	currSection = -1;
	while (1)
	{
		if ((ch = fgetc(asmFile)) != EOF)
		{
			if ((ch == 10) || (ch == 13))
			{
				if (oneLine.length())
				{
					if (oneLine.find(".ramsection \"ram.data\"") != string::npos)
					{
						saveCode = true;
						currSection = 0;
						asmSections[currSection].push_back(oneLine);
					}
					else if (oneLine.find(".section \".data\"") != string::npos)
					{
						saveCode = true;
						currSection = 1;
						asmSections[currSection].push_back(oneLine);
					}
					else if (oneLine.find(".section \".rodata\"") != string::npos)
					{
						saveCode = true;
						currSection = 2;
						asmSections[currSection].push_back(oneLine);
					}
					else if (oneLine.find(".ends") != string::npos)
					{
						saveCode = false;
						if (currSection == 2) break;
						if (currSection >= 0)
							asmSections[currSection].push_back(oneLine);
						else
							fprintf(outFile, "%s\n", oneLine.data());
					}
					else if (saveCode)
					{
						asmSections[currSection].push_back(oneLine);
					}
					else
					{
						fprintf(outFile, "%s\n", oneLine.data());
					}
				}
				oneLine.clear();
			}
			else
			{
				oneLine += (char)ch;
			}
		}
		else
		{
			break;
		}
	}

	varsMoved = bytesMoved = 0;
	vector<string>::iterator it;

	for (i = 0; i < constVars.size(); i++)
	{
		int k,m,n;
		j = 1;
		varOffs = 0;
		while (j < asmSections[0].size())
		{
			if (asmSections[0][j].find(constVars[i]) != string::npos)
			{
				break;
			}
			else
			{
				k = asmSections[0][j].find("dsb");
				if (k != string::npos)
				{
					varOffs += atoi(asmSections[0][j].substr(k + 4).data());
				}
			}
			j++;
		}

		if (j < asmSections[0].size())
		{
			k = asmSections[0][j].find("dsb");
			if (k != string::npos)
			{
				varSize = atoi(asmSections[0][j].substr(k + 4).data());
			}
			int dataOffs = 0;
			m = 1;
			while ((dataOffs < varOffs) && (m < asmSections[1].size()))
			{
				n = 1;
				if (asmSections[1][m].find(".dw") != string::npos) n = 2;
				for (int p = 0; p < asmSections[1][m].size(); p++)
				{
					if (asmSections[1][m][p] == ',') dataOffs += n;
				}
				dataOffs += n;
				m++;
			}
			int dataStart = m, q = 0;
			while ((q < varSize) && (m < asmSections[1].size()))
			{
				n = 1;
				if (asmSections[1][m].find(".dw") != string::npos) n = 2;
				for (int p = 0; p < asmSections[1][m].size(); p++)
				{
					if (asmSections[1][m][p] == ',') q += n;
				}
				q += n;
				m++;
			}
			asmSections[2].push_back(constVars[i] + ":");
			for (k = dataStart; k < m; k++)
			{
				asmSections[2].push_back(asmSections[1][dataStart]);
				it = asmSections[1].begin();
				advance(it, dataStart);
				asmSections[1].erase(it);
			}
			it = asmSections[0].begin();
			advance(it, j);
			asmSections[0].erase(it);
			bytesMoved += varSize;
			varsMoved++;
		}
		//printf("%s at offset %d\n", constVars[i].data(), varOffs);
	}

	printf("Done! Moved %d variables (%d bytes)\n", varsMoved, bytesMoved);
	for (i = 0; i < 3; i++)
	{
		for (j = 0; j < asmSections[i].size(); j++)
		{
			fprintf(outFile, "%s\n", asmSections[i][j].data());
		}
	}
	fputs(".ends\n\n", outFile);

	while ((ch = fgetc(asmFile)) != EOF)
	{
		fputc(ch, outFile);
	}

	fclose(asmFile);
	fclose(outFile);
	asmSections[0].clear();
	asmSections[1].clear();
	asmSections[2].clear();
	constVars.clear();

	return 0;
}
